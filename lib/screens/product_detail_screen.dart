import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedSize;
  String? _selectedColor;
  bool _added = false;

  void _addToCart() {
    if (_selectedSize == null || _selectedColor == null) return;
    context.read<CartProvider>().addItem(widget.product, _selectedSize!, _selectedColor!);
    setState(() => _added = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _added = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final canAdd = _selectedSize != null && _selectedColor != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.55,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Color(0xFF1C1917)),
            actions: [
              Consumer<CartProvider>(
                builder: (_, cart, _) => Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1C1917)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
                    ),
                    if (cart.itemCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(color: Color(0xFF1C1917), shape: BoxShape.circle),
                          child: Center(
                            child: Text('${cart.itemCount}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: p.image,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  if (p.badge != null)
                    Positioned(
                      top: 60,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: const Color(0xFF1C1917), borderRadius: BorderRadius.circular(20)),
                        child: Text(p.badge!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.category.toUpperCase(), style: const TextStyle(fontSize: 11, color: Color(0xFFA8A29E), letterSpacing: 1.5)),
                  const SizedBox(height: 6),
                  Text(p.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF1C1917))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ...List.generate(5, (i) => Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: i < p.rating.floor() ? const Color(0xFFFBBF24) : const Color(0xFFE7E5E4),
                      )),
                      const SizedBox(width: 6),
                      Text('${p.rating} · ${p.reviews} reviews', style: const TextStyle(fontSize: 12, color: Color(0xFFA8A29E))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('₹${p.price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF1C1917))),
                      if (p.originalPrice != null) ...[
                        const SizedBox(width: 10),
                        Text('₹${p.originalPrice!.toStringAsFixed(0)}', style: const TextStyle(fontSize: 18, color: Color(0xFFA8A29E), decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            'Save ₹${(p.originalPrice! - p.price).toStringAsFixed(0)}',
                            style: const TextStyle(color: Color(0xFF065F46), fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(p.description, style: const TextStyle(fontSize: 14, color: Color(0xFF78716C), height: 1.6)),
                  const SizedBox(height: 24),

                  // Color
                  _OptionLabel(label: 'Color', selected: _selectedColor),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: p.colors.map((c) {
                      final isSelected = _selectedColor == c;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColor = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1C1917) : Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: isSelected ? const Color(0xFF1C1917) : const Color(0xFFE7E5E4)),
                          ),
                          child: Text(c, style: TextStyle(fontSize: 13, color: isSelected ? Colors.white : const Color(0xFF57534E), fontWeight: FontWeight.w500)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Size
                  _OptionLabel(label: 'Size', selected: _selectedSize),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: p.sizes.map((s) {
                      final isSelected = _selectedSize == s;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSize = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF1C1917) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isSelected ? const Color(0xFF1C1917) : const Color(0xFFE7E5E4)),
                          ),
                          child: Center(
                            child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : const Color(0xFF57534E))),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),

                  // Add to cart
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton.icon(
                        onPressed: canAdd ? _addToCart : null,
                        icon: Icon(_added ? Icons.check : Icons.shopping_bag_outlined, size: 18),
                        label: Text(
                          _added ? 'Added to Cart' : (!canAdd ? 'Select size & colour' : 'Add to Cart'),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _added ? const Color(0xFF059669) : const Color(0xFF1C1917),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFF5F5F4),
                          disabledForegroundColor: const Color(0xFFA8A29E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFFF5F5F4)),
                  _DetailRow(label: 'Material', value: '100% Organic Cotton'),
                  _DetailRow(label: 'Shipping', value: 'Free over ₹75'),
                  _DetailRow(label: 'Returns', value: '30 days'),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionLabel extends StatelessWidget {
  final String label;
  final String? selected;
  const _OptionLabel({required this.label, this.selected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1C1917))),
        if (selected != null) ...[
          const Text(' — ', style: TextStyle(color: Color(0xFFA8A29E))),
          Text(selected!, style: const TextStyle(fontSize: 14, color: Color(0xFFA8A29E))),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFFA8A29E))),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1C1917))),
        ],
      ),
    );
  }
}
