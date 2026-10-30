import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/failure_message.dart';
import '../../auth/bloc/session_cubit.dart';
import '../bloc/products_bloc.dart';
import 'widgets/product_tile.dart';
import 'widgets/state_views.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.select((SessionCubit c) => c.state.user);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          if (user?.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(user!.imageUrl!),
                onBackgroundImageError: (_, _) {}, // an avatar isn't worth an error
              ),
            ),
          IconButton(
            key: const Key('products.logout'),
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<SessionCubit>().logout(),
          ),
        ],
      ),
      body: BlocListener<ProductsBloc, ProductsState>(
        listenWhen: (previous, current) =>
            current.refreshFailure != null && previous.refreshFailure != current.refreshFailure,
        listener: (context, state) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failureMessage(state.refreshFailure!)))),
        child: BlocBuilder<ProductsBloc, ProductsState>(
          buildWhen: (previous, current) => previous.status != current.status || previous.isEmpty != current.isEmpty,
          builder: (context, state) => switch (state.status) {
            ProductsStatus.initial ||
            ProductsStatus.loading => const Center(key: Key('products.loading'), child: CircularProgressIndicator()),
            ProductsStatus.failure => MessageView(
              key: const Key('products.error'),
              icon: Icons.cloud_off_rounded,
              title: 'Couldn\'t load products',
              message: failureMessage(state.failure!),
              actionLabel: 'Try again',
              onAction: () => context.read<ProductsBloc>().add(const ProductsStarted()),
            ),
            ProductsStatus.success when state.isEmpty => _Refreshable(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: constraints.maxHeight,
                    child: const MessageView(
                      key: Key('products.empty'),
                      icon: Icons.inventory_2_outlined,
                      title: 'No products yet',
                      message: 'Pull down to check again.',
                    ),
                  ),
                ),
              ),
            ),
            ProductsStatus.success => const _Refreshable(child: _ProductList()),
          },
        ),
      ),
    );
  }
}

class _Refreshable extends StatelessWidget {
  const _Refreshable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () {
      final event = ProductsRefreshed();
      context.read<ProductsBloc>().add(event);
      return event.done.future;
    },
    child: child,
  );
}

class _ProductList extends StatefulWidget {
  const _ProductList();

  @override
  State<_ProductList> createState() => _ProductListState();
}

class _ProductListState extends State<_ProductList> {
  final _scroll = ScrollController();

  /// Start loading the next page this far before the end, so scrolling
  /// rarely reaches the loader.
  static const _prefetchExtent = 600.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels <= _prefetchExtent) _requestNextPage();
  }

  void _requestNextPage() {
    final bloc = context.read<ProductsBloc>();
    final state = bloc.state;
    if (state.isLoadingMore || state.hasReachedEnd || state.loadMoreFailure != null) return;
    bloc.add(ProductsNextPageRequested(state.nextSkip));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ProductsBloc>().state;
    // A short first page may not fill the screen, so no scroll event would
    // ever ask for more. Check once the frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onScroll();
    });

    return ListView.builder(
      key: const Key('products.list'),
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + 1,
      itemBuilder: (context, index) {
        if (index < state.items.length) {
          final product = state.items[index];
          return ProductTile(
            key: ValueKey(product.id),
            product: product,
            onTap: () => unawaited(context.push(_detailPath(product.id), extra: product)),
          );
        }
        return _ListFooter(
          state: state,
          onRetry: () => context.read<ProductsBloc>().add(ProductsNextPageRequested(state.nextSkip, isRetry: true)),
        );
      },
    );
  }

  static String _detailPath(int id) => '/products/$id';
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.onRetry});

  final ProductsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget child;
    if (state.loadMoreFailure != null) {
      child = Column(
        key: const Key('products.loadMoreError'),
        children: [
          Text(failureMessage(state.loadMoreFailure!), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      );
    } else if (state.hasReachedEnd) {
      child = Text(
        'You\'ve seen all ${state.items.length} products',
        key: const Key('products.end'),
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
      );
    } else {
      child = const SizedBox.square(
        key: Key('products.loadingMore'),
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(child: child),
    );
  }
}
