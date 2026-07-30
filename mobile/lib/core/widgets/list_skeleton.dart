import 'package:flutter/material.dart';

/// Placeholder rows shown while the first page is in flight, so the screen
/// keeps its shape instead of flashing a bare spinner.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const Card(
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(backgroundColor: _skeletonColor),
          title: SkeletonBar(widthFactor: 0.6),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 6),
            child: SkeletonBar(widthFactor: 0.35, height: 10),
          ),
        ),
      ),
    );
  }
}

const _skeletonColor = Color(0xFFE3E7ED);

class SkeletonBar extends StatelessWidget {
  const SkeletonBar({super.key, required this.widthFactor, this.height = 13});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: _skeletonColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}

/// Centered footer spinner for "loading the next page".
class PageLoadingFooter extends StatelessWidget {
  const PageLoadingFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
