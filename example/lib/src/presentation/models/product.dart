class Product {
  final String? id;
  final String? name;
  final String? description;
  final String? image;
  final String? price;
  final String? category;
  final String? brand;
  final String? color;

  Product({
    this.id,
    this.name,
    this.description,
    this.image,
    this.price,
    this.category,
    this.brand,
    this.color,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      image: json['image'],
      price: json['price'],
      category: json['category'],
      brand: json['brand'],
      color: json['color'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image': image,
      'price': price,
      'category': category,
      'brand': brand,
      'color': color,
    };
  }
}
