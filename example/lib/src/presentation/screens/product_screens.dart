import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';

import '../../app_router.dart';
import '../models/product.dart';
import '../widgets/location_bar.dart';
import '../widgets/route_button.dart';

/// How a product list is ordered. Enums round-trip through the URL by name.
enum ProductSort {
  /// Cheapest first.
  priceAsc,

  /// Most expensive first.
  priceDesc,

  /// Highest rated first.
  rating,
}

/// A product list with a typed enum sort and a repeated `tag` filter.
@AutoGoRoute(
  path: '/products',
  name: 'productList',
  description: 'Product list with typed enum and list query parameters.',
)
class ProductListRoute extends StatelessWidget {
  /// Creates the product list.
  const ProductListRoute({
    super.key,
    this.sort = ProductSort.rating,
    this.tags,
    this.page = 1,
  });

  /// Read from `?sort=priceAsc`, decoded into the enum.
  final ProductSort sort;

  /// Read from a repeated key: `?tags=new&tags=sale`.
  final List<String>? tags;

  /// Read from `?page=2`, decoded into an `int`.
  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        bottom: const LocationBar(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final option in ProductSort.values)
                ChoiceChip(
                  label: Text(option.name),
                  selected: option == sort,
                  onSelected: (_) => context.replaceInPlaceWithProductList(
                    sort: option,
                    tags: tags,
                    page: page,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'page $page · tags: ${tags?.join(', ') ?? 'none'}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          for (var index = 0; index < 5; index++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 5),
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Text('${index + 1}'),
                ),
                title: Text('Product ${index + 1}'),
                subtitle: Text('sorted by ${sort.name}'),
                trailing: Text(
                  '\$${(index + 1) * 25}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () => context.pushToProductDetails(id: index + 1),
              ),
            ),
          const SizedBox(height: 8),
          RouteButton(
            label: 'Next page',
            subtitle: context.locationOfProductList(
              sort: sort,
              tags: tags,
              page: page + 1,
            ),
            icon: Icons.navigate_next_rounded,
            onPressed: () => context.replaceInPlaceWithProductList(
              sort: sort,
              tags: tags,
              page: page + 1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Product details, with an `int` path parameter and a `Product` in `extra`.
@AutoGoRoute(
  path: r'/products/:id(\d+)',
  name: 'productDetails',
  description: 'Product details. The path parameter is constrained to digits.',
)
class ProductDetailsRoute extends StatelessWidget {
  /// Creates the details screen.
  const ProductDetailsRoute({
    super.key,
    required this.id,
    this.name,
    this.product,
  });

  /// Read from the path and decoded into an `int`. Passing a string is a
  /// compile error at the call site.
  final int id;

  /// Read from `?name=`.
  final String? name;

  /// Carried in `state.extra` — it cannot be expressed in a URL, so the screen
  /// still works from a cold deep link, just without it.
  final Product? product;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product details'),
        bottom: const LocationBar(),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [scheme.primaryContainer, scheme.secondaryContainer],
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_rounded,
                  size: 48,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  'Product #$id',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ParamTable(
            title: 'Decoded by the generated builder',
            rows: [
              ('id', 'path', '$id  (int)'),
              ('name', 'query', name ?? 'null'),
              ('product', 'extra', product == null ? 'null' : 'Product'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Extra: ${product?.toJson() ?? 'not passed (deep link)'}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
          ),
          const SectionLabel('Nested routes'),
          RouteButton(
            label: 'Reviews',
            subtitle: context.locationOfProductReviews(id: id),
            icon: Icons.reviews_outlined,
            onPressed: () => context.pushToProductReviews(id: id),
          ),
          RouteButton(
            label: 'Offers',
            subtitle: context.locationOfProductOffers(id: id),
            icon: Icons.local_offer_outlined,
            onPressed: () => context.pushToProductOffers(id: id),
          ),
        ],
      ),
    );
  }
}

/// Nested under [ProductDetailsRoute], so its path is relative.
@AutoGoRoute(
  path: 'reviews',
  parent: ProductDetailsRoute,
  name: 'productReviews',
  transition: AutoRouteTransition.fade,
)
class ProductReviewsRoute extends StatelessWidget {
  /// Creates the reviews screen.
  const ProductReviewsRoute({super.key, required this.id});

  /// Inherited from the parent's path.
  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Reviews for #$id'),
      bottom: const LocationBar(),
    ),
    body: Center(child: Text('Reviews for product $id')),
  );
}

/// Nested under [ProductDetailsRoute].
@AutoGoRoute(path: 'offers', parent: ProductDetailsRoute, name: 'productOffers')
class ProductOffersRoute extends StatelessWidget {
  /// Creates the offers screen.
  const ProductOffersRoute({super.key, required this.id});

  /// Inherited from the parent's path.
  final int id;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Offers for #$id'), bottom: const LocationBar()),
    body: Center(child: Text('Offers for product $id')),
  );
}
