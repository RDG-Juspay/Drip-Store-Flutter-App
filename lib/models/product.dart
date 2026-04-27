class Product {
  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final String category;
  final String image;
  final List<String> images;
  final String description;
  final List<String> sizes;
  final List<String> colors;
  final String? badge;
  final double rating;
  final int reviews;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.category,
    required this.image,
    required this.images,
    required this.description,
    required this.sizes,
    required this.colors,
    this.badge,
    required this.rating,
    required this.reviews,
  });
}

final List<Product> products = [
  Product(
    id: '1',
    name: 'Classic White Tee',
    price: 29,
    originalPrice: 45,
    category: 'Men',
    image: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=600&q=80'],
    description: 'A timeless essential. Ultra-soft classic tee crafted from 100% organic cotton for all-day comfort.',
    sizes: ['XS', 'S', 'M', 'L', 'XL'],
    colors: ['White', 'Black', 'Grey'],
    badge: 'Sale',
    rating: 4.8,
    reviews: 124,
  ),
  Product(
    id: '2',
    name: 'Slim Fit Chinos',
    price: 79,
    category: 'Men',
    image: 'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=600&q=80'],
    description: 'Tailored slim-fit chinos with a modern cut. Perfect for office or weekend outings.',
    sizes: ['S', 'M', 'L', 'XL'],
    colors: ['Beige', 'Navy', 'Olive'],
    rating: 4.6,
    reviews: 89,
  ),
  Product(
    id: '3',
    name: 'Floral Wrap Dress',
    price: 65,
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=600&q=80'],
    description: 'A breezy floral wrap dress perfect for sunny days. Flowing silhouette with adjustable tie waist.',
    sizes: ['XS', 'S', 'M', 'L'],
    colors: ['Floral Pink', 'Floral Blue'],
    badge: 'New',
    rating: 4.9,
    reviews: 203,
  ),
  Product(
    id: '4',
    name: 'Oversized Hoodie',
    price: 89,
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=600&q=80'],
    description: 'Cozy oversized hoodie in premium fleece. The perfect layering piece for cooler days.',
    sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
    colors: ['Cream', 'Dusty Rose', 'Sage'],
    rating: 4.7,
    reviews: 156,
  ),
  Product(
    id: '5',
    name: 'Denim Jacket',
    price: 120,
    originalPrice: 160,
    category: 'Men',
    image: 'https://images.unsplash.com/photo-1551537482-f2075a1d41f2?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1551537482-f2075a1d41f2?w=600&q=80'],
    description: 'Classic denim jacket with a modern fit, button-front closure and chest pockets.',
    sizes: ['S', 'M', 'L', 'XL'],
    colors: ['Light Wash', 'Dark Wash'],
    badge: 'Sale',
    rating: 4.5,
    reviews: 78,
  ),
  Product(
    id: '6',
    name: 'Linen Co-ord Set',
    price: 110,
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1509631179647-0177331693ae?w=600&q=80'],
    description: 'Effortlessly chic linen co-ord set. Breathable and lightweight, ideal for warm weather.',
    sizes: ['XS', 'S', 'M', 'L'],
    colors: ['White', 'Camel', 'Terracotta'],
    badge: 'New',
    rating: 4.8,
    reviews: 91,
  ),
  Product(
    id: '7',
    name: 'Graphic Sweatshirt',
    price: 55,
    category: 'Unisex',
    image: 'https://images.unsplash.com/photo-1556821840-3a63f15732ce?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1556821840-3a63f15732ce?w=600&q=80'],
    description: 'Bold graphic sweatshirt in heavyweight cotton blend. A statement piece for every wardrobe.',
    sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
    colors: ['Black', 'White', 'Navy'],
    rating: 4.4,
    reviews: 67,
  ),
  Product(
    id: '8',
    name: 'High-Rise Joggers',
    price: 68,
    category: 'Women',
    image: 'https://images.unsplash.com/photo-1506629082955-511b1aa562c8?w=600&q=80',
    images: ['https://images.unsplash.com/photo-1506629082955-511b1aa562c8?w=600&q=80'],
    description: 'High-rise joggers in soft French terry. Comfortable enough for lounging, stylish enough for errands.',
    sizes: ['XS', 'S', 'M', 'L', 'XL'],
    colors: ['Black', 'Charcoal', 'Blush'],
    rating: 4.6,
    reviews: 112,
  ),
];

const List<String> categories = ['All', 'Men', 'Women', 'Unisex'];
