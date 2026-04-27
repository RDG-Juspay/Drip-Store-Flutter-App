import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
import '../widgets/product_card.dart';
import 'products_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final featured = products.take(4).toList();
    final newArrivals = products.where((p) => p.badge == 'New').toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroBanner(),
          _SectionTitle(title: 'Shop by Category', padding: const EdgeInsets.fromLTRB(20, 32, 20, 16)),
          _CategoryGrid(),
          _SectionTitle(
            title: 'Featured Picks',
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
            actionLabel: 'View all',
            onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
          ),
          _ProductGrid(items: featured),
          _SaleBanner(),
          if (newArrivals.isNotEmpty) ...[
            _SectionTitle(
              title: 'New Arrivals',
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              actionLabel: 'View all',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
            ),
            _ProductGrid(items: newArrivals),
          ],
          _USPRow(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.65,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=85',
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: const Color(0xFF1C1917)),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC1C1917)],
                stops: [0.3, 1.0],
              ),
            ),
          ),
          Positioned(
            bottom: 48,
            left: 24,
            right: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SPRING / SUMMER 2024',
                  style: TextStyle(color: Color(0xFFD6D3D1), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Dress for\nthe moment.',
                  style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Curated essentials for every occasion.',
                  style: TextStyle(color: Color(0xFFD6D3D1), fontSize: 15),
                ),
                const SizedBox(height: 24),
                Builder(builder: (context) => GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Shop Now', style: TextStyle(color: Color(0xFF1C1917), fontWeight: FontWeight.w700, fontSize: 14)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 16, color: Color(0xFF1C1917)),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final _cats = const [
    {'label': 'Men', 'image': 'https://images.unsplash.com/photo-1617137968427-85924c800a22?w=600&q=80', 'category': 'Men'},
    {'label': 'Women', 'image': 'https://images.unsplash.com/photo-1469334031218-e382a71b716b?w=600&q=80', 'category': 'Women'},
    {'label': 'Unisex', 'image': 'https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=600&q=80', 'category': 'Unisex'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _cats.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final cat = _cats[i];
          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductsScreen(initialCategory: cat['category']!)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(imageUrl: cat['image']!, fit: BoxFit.cover),
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xCC1C1917)],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 14,
                      child: Text(
                        cat['label']!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<Product> items;
  const _ProductGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 20,
          childAspectRatio: 0.62,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => ProductCard(product: items[i]),
      ),
    );
  }
}

class _SaleBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 200,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: 'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=800&q=80',
                fit: BoxFit.cover,
              ),
              Container(color: const Color(0x881C1917)),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('LIMITED TIME', style: TextStyle(color: Color(0xFFD6D3D1), fontSize: 11, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    const Text('Up to 40% Off', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductsScreen())),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: const Text('Shop the Sale', style: TextStyle(color: Color(0xFF1C1917), fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _USPRow extends StatelessWidget {
  final _usps = const [
    {'icon': Icons.local_shipping_outlined, 'title': 'Free Shipping', 'desc': 'Over ₹75'},
    {'icon': Icons.replay_outlined, 'title': 'Easy Returns', 'desc': '30 days'},
    {'icon': Icons.lock_outline, 'title': 'Secure', 'desc': '100% safe'},
    {'icon': Icons.eco_outlined, 'title': 'Sustainable', 'desc': 'Ethically made'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      color: const Color(0xFFF5F5F4),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: _usps.map((u) => Column(
          children: [
            Icon(u['icon'] as IconData, size: 26, color: const Color(0xFF57534E)),
            const SizedBox(height: 6),
            Text(u['title'] as String, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1C1917))),
            Text(u['desc'] as String, style: const TextStyle(fontSize: 10, color: Color(0xFFA8A29E))),
          ],
        )).toList(),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  const _SectionTitle({required this.title, this.actionLabel, this.onAction, required this.padding});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1C1917))),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(actionLabel!, style: const TextStyle(fontSize: 13, color: Color(0xFFA8A29E))),
            ),
        ],
      ),
    );
  }
}
