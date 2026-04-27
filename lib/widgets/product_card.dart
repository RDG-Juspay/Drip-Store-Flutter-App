import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../screens/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: product.image,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: const Color(0xFFF5F5F4)),
                    errorWidget: (_, _, _) => Container(color: const Color(0xFFF5F5F4)),
                  ),
                ),
                if (product.badge != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1917),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        product.badge!,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            product.category.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Color(0xFFA8A29E), letterSpacing: 1.2),
          ),
          const SizedBox(height: 2),
          Text(
            product.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1917)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 13, color: Color(0xFFFBBF24)),
              const SizedBox(width: 2),
              Text(
                '${product.rating} (${product.reviews})',
                style: const TextStyle(fontSize: 11, color: Color(0xFFA8A29E)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '₹${product.price.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1C1917)),
              ),
              if (product.originalPrice != null) ...[
                const SizedBox(width: 6),
                Text(
                  '₹${product.originalPrice!.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFA8A29E), decoration: TextDecoration.lineThrough),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
