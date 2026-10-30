import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/failure_message.dart';
import '../bloc/product_detail_cubit.dart';
import '../data/product.dart';
import 'widgets/state_views.dart';

/// Shows what the list already knew right away (image, title, price) and
/// fills in the rest when the details arrive. Reached without the list's
/// summary (e.g. `context.go('/products/7')`), it starts with a loader.
class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductDetailCubit>().state;
    final summary = state.summary;
    final retry = context.read<ProductDetailCubit>().load;

    if (summary == null) {
      return Scaffold(
        appBar: AppBar(),
        body: state.failure != null
            ? MessageView(
                key: const Key('detail.error'),
                icon: Icons.cloud_off_rounded,
                title: 'Couldn\'t load this product',
                message: failureMessage(state.failure!),
                actionLabel: 'Try again',
                onAction: retry,
              )
            : const Center(key: Key('detail.loading'), child: CircularProgressIndicator()),
      );
    }

    final details = state.details;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 340,
            flexibleSpace: FlexibleSpaceBar(
              background: _Gallery(
                heroTag: 'product-${summary.id}',
                urls: details?.imageUrls.isNotEmpty ?? false ? details!.imageUrls : [summary.thumbnailUrl],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            sliver: SliverList.list(
              children: [
                _Header(summary: summary, availability: details?.availabilityStatus),
                const SizedBox(height: 24),
                if (details != null)
                  _Details(details: details)
                else if (state.failure != null)
                  _InlineError(message: failureMessage(state.failure!), onRetry: retry)
                else
                  const Padding(
                    key: Key('detail.loading'),
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.heroTag, required this.urls});

  final String heroTag;
  final List<String> urls;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerLow,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (page) => setState(() => _page = page),
            itemBuilder: (context, index) {
              final image = ProductImage(widget.urls[index], fit: BoxFit.contain);
              return Padding(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 32),
                // Only the first image flies in from the list, and only the
                // image itself, so it has a size for the whole flight.
                child: index == 0 ? Hero(tag: widget.heroTag, child: image) : image,
              );
            },
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.urls.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? colors.primary : colors.outlineVariant,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.summary, this.availability});

  final ProductSummary summary;
  final String? availability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDiscount = summary.discountPercentage >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [if (summary.brand != null) summary.brand!, summary.category].join(' · ').toUpperCase(),
          style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, letterSpacing: 0.8),
        ),
        const SizedBox(height: 6),
        Text(summary.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              formatPrice(summary.price),
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (hasDiscount) ...[
              Text(
                formatPrice(summary.originalPrice),
                semanticsLabel: 'was ${formatPrice(summary.originalPrice)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: theme.colorScheme.outline,
                ),
              ),
              _Pill(text: '-${summary.discountPercentage.round()}%', color: theme.colorScheme.tertiaryContainer),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _Pill(
              icon: Icons.star_rounded,
              iconColor: Colors.amber.shade600,
              text: summary.rating.toStringAsFixed(1),
              color: theme.colorScheme.surfaceContainerHigh,
            ),
            _Pill(
              text: availability ?? (summary.stock > 0 ? 'In Stock' : 'Out of Stock'),
              color: summary.stock > 0 ? theme.colorScheme.secondaryContainer : theme.colorScheme.errorContainer,
            ),
            _Pill(text: '${summary.stock} left', color: theme.colorScheme.surfaceContainerHigh),
          ],
        ),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.details});

  final ProductDetails details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = [
      (Icons.local_shipping_outlined, details.shippingInformation),
      (Icons.verified_user_outlined, details.warrantyInformation),
      (Icons.assignment_return_outlined, details.returnPolicy),
    ].where((row) => row.$2 != null);

    return Column(
      key: const Key('detail.content'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(details.description, style: theme.textTheme.bodyLarge),
        if (info.isNotEmpty) ...[
          const SizedBox(height: 20),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                for (final (icon, text) in info) ListTile(dense: true, leading: Icon(icon), title: Text(text!)),
              ],
            ),
          ),
        ],
        if (details.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in details.tags) Chip(label: Text('#$tag'), visualDensity: VisualDensity.compact),
            ],
          ),
        ],
        if (details.reviews.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text('Reviews (${details.reviews.length})', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final review in details.reviews) _ReviewTile(review: review),
        ],
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A Wrap, not a Row: with large text the date moves to its own line.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                label: 'rated ${review.rating} out of 5',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 1; i <= 5; i++)
                        Icon(
                          i <= review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 16,
                          color: Colors.amber.shade600,
                        ),
                    ],
                  ),
                ),
              ),
              Text(review.reviewerName, style: theme.textTheme.labelLarge),
              Text(
                MaterialLocalizations.of(context).formatShortDate(review.date.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(review.comment, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('detail.error'),
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: Text(message)),
          const SizedBox(width: 12),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.icon, this.iconColor});

  final String text;
  final Color color;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16, color: iconColor), const SizedBox(width: 4)],
          Text(text, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    ),
  );
}

/// For a malformed product link such as `/products/abc`.
class ProductNotFoundPage extends StatelessWidget {
  const ProductNotFoundPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: MessageView(
      icon: Icons.search_off_rounded,
      title: 'Product not found',
      message: 'This link doesn\'t point to a product.',
      actionLabel: 'Back to products',
      onAction: () => context.go('/products'),
    ),
  );
}
