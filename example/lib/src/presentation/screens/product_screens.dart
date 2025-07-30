// lib/src/presentation/screens/product_screens.dart
import 'package:auto_go_route/auto_go_route.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../main.dart';
import '../widgets/route_button.dart';

@AutoGoRoute(path: '/products')
class ProductListRoute extends StatelessWidget {
  const ProductListRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Products')),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          final productId = 'product-${index + 1}';
          return ListTile(
            title: Text('Product ${index + 1}'),
            onTap: () => context.push(
              appRouter.productDetailsRouteRoute.pathWithParams({
                'id': productId,
              }),
            ),
          );
        },
      ),
    );
  }
}

@AutoGoRoute(path: '/products/:id')
class ProductDetailsRoute extends StatelessWidget {
  final String id;
  const ProductDetailsRoute({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Product Details')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Showing details for Product ID: $id',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              RouteButton(
                label: 'View Reviews for this Product',
                onPressed: () => context.push(
                  appRouter.productReviewsRouteRoute.pathWithParams({'id': id}),
                ),
              ),
              const SizedBox(height: 10),
              RouteButton(
                label: 'View Offers for this Product',
                onPressed: () => context.push(
                  appRouter.productOffersRouteRoute.pathWithParams({'id': id}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// This is a nested route. Its parent is ProductDetailsRoute.
@AutoGoRoute(path: 'reviews', parent: ProductDetailsRoute)
class ProductReviewsRoute extends StatelessWidget {
  final String id;
  const ProductReviewsRoute({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    // The full path will be /products/:id/reviews
    return Scaffold(
      appBar: AppBar(title: Text('Reviews for $id')),
      body: Center(
        child: Text(
          'Showing reviews for Product ID: $id',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

// Another nested route.
@AutoGoRoute(path: 'offers', parent: ProductDetailsRoute)
class ProductOffersRoute extends StatelessWidget {
  final String id;
  const ProductOffersRoute({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    // The full path will be /products/:id/offers
    return Scaffold(
      appBar: AppBar(title: Text('Offers for $id')),
      body: Center(
        child: Text(
          'Showing special offers for Product ID: $id',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
