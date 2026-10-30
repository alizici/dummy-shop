import 'package:equatable/equatable.dart';

import '../../../core/json/json_reader.dart';

/// What the list needs about a product. The list requests only these fields
/// (`select=`), so a page stays small.
class ProductSummary extends Equatable {
  const ProductSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.price,
    required this.discountPercentage,
    required this.rating,
    required this.stock,
    required this.thumbnailUrl,
    this.brand,
  });

  factory ProductSummary.fromJson(JsonReader json) => ProductSummary(
    id: json.integer('id'),
    title: json.string('title'),
    category: json.string('category'),
    price: json.number('price'),
    discountPercentage: json.number('discountPercentage'),
    rating: json.number('rating'),
    stock: json.integer('stock'),
    thumbnailUrl: json.string('thumbnail'),
    // DummyJSON leaves `brand` out for some products (groceries, ...).
    brand: json.stringOrNull('brand'),
  );

  /// The fields [ProductSummary.fromJson] reads, for the `select` parameter.
  static const fields = [
    'id',
    'title',
    'category',
    'price',
    'discountPercentage',
    'rating',
    'stock',
    'thumbnail',
    'brand',
  ];

  final int id;
  final String title;
  final String category;
  final double price;
  final double discountPercentage;
  final double rating;
  final int stock;
  final String thumbnailUrl;
  final String? brand;

  /// Price before the discount, for a struck-through "was" price.
  double get originalPrice => discountPercentage <= 0 ? price : price / (1 - discountPercentage / 100);

  @override
  List<Object?> get props => [id, title, category, price, discountPercentage, rating, stock, thumbnailUrl, brand];
}

/// Everything the detail page shows.
class ProductDetails extends Equatable {
  const ProductDetails({
    required this.summary,
    required this.description,
    required this.imageUrls,
    required this.tags,
    required this.reviews,
    this.availabilityStatus,
    this.shippingInformation,
    this.warrantyInformation,
    this.returnPolicy,
  });

  factory ProductDetails.fromJson(JsonReader json) => ProductDetails(
    summary: ProductSummary.fromJson(json),
    description: json.string('description'),
    imageUrls: json.stringListOrEmpty('images'),
    tags: json.stringListOrEmpty('tags'),
    reviews: json.objectsOrEmpty('reviews', Review.fromJson),
    availabilityStatus: json.stringOrNull('availabilityStatus'),
    shippingInformation: json.stringOrNull('shippingInformation'),
    warrantyInformation: json.stringOrNull('warrantyInformation'),
    returnPolicy: json.stringOrNull('returnPolicy'),
  );

  final ProductSummary summary;
  final String description;
  final List<String> imageUrls;
  final List<String> tags;
  final List<Review> reviews;
  final String? availabilityStatus;
  final String? shippingInformation;
  final String? warrantyInformation;
  final String? returnPolicy;

  @override
  List<Object?> get props => [
    summary,
    description,
    imageUrls,
    tags,
    reviews,
    availabilityStatus,
    shippingInformation,
    warrantyInformation,
    returnPolicy,
  ];
}

class Review extends Equatable {
  const Review({required this.rating, required this.comment, required this.reviewerName, required this.date});

  factory Review.fromJson(JsonReader json) => Review(
    rating: json.integer('rating'),
    comment: json.string('comment'),
    reviewerName: json.string('reviewerName'),
    date: json.dateTime('date'),
  );

  final int rating;
  final String comment;
  final String reviewerName;
  final DateTime date;

  @override
  List<Object?> get props => [rating, comment, reviewerName, date];
}

/// One page of the product list.
class ProductPage extends Equatable {
  const ProductPage({required this.items, required this.total, required this.skip});

  factory ProductPage.fromJson(JsonReader json) => ProductPage(
    items: json.objects('products', ProductSummary.fromJson),
    total: json.integer('total'),
    skip: json.integer('skip'),
  );

  final List<ProductSummary> items;

  /// How many products exist in total, across all pages.
  final int total;

  /// How many products come before this page.
  final int skip;

  @override
  List<Object?> get props => [items, total, skip];
}
