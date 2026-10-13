import 'package:flutter/material.dart';

import 'palette.dart';

/// Floating navigation with animated selection and accessible tab labels.
/// Tab state and destinations are owned by HomeShell; navigation never fakes data.
class PremiumNavigationBar extends StatelessWidget {
  const PremiumNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.labels,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<String> labels;

  static const _icons = <IconData>[
    Icons.radar_outlined,
    Icons.people_outline_rounded,
    Icons.forum_outlined,
    Icons.person_outline_rounded,
  ];

  static const _selectedIcons = <IconData>[
    Icons.radar_rounded,
    Icons.people_rounded,
    Icons.forum_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    assert(labels.length == 4);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 3, 12, 10),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF252037),
                Color(0xFF151526),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: const Color(0xFFFFAED6).withValues(alpha: .17),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .34),
                blurRadius: 24,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Row(
            children: List.generate(labels.length, (index) {
              final selected = index == selectedIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: labels[index],
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: ValueKey('premium-nav-$index'),
                      onTap: () => onDestinationSelected(index),
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 290),
                        curve: Curves.easeOutCubic,
                        constraints: const BoxConstraints(minHeight: 61),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: selected
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFB53C84),
                                    Color(0xFF6937A9),
                                  ],
                                )
                              : null,
                          border: selected
                              ? Border.all(
                                  color: Colors.white.withValues(alpha: .17),
                                  width: 1,
                                )
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: reduceMotion
                                  ? Duration.zero
                                  : const Duration(milliseconds: 220),
                              child: Icon(
                                selected ? _selectedIcons[index] : _icons[index],
                                key: ValueKey('$index-$selected'),
                                color: selected ? Colors.white : Palette.secondary,
                                size: 23,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: selected ? Colors.white : Palette.secondary,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                fontSize: 10.5,
                                letterSpacing: -.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
