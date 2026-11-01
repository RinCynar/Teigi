import 'package:flutter/material.dart';
import 'package:teigi/theme/tokens.dart';

/// 桌面端侧边栏导航目标定义。
class DesktopNavDestination {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;

  const DesktopNavDestination({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });
}

/// 桌面端侧边导航栏，1:1 对齐 0rhxPlayer-Desktop 的 NavigationRail.qml 实现。
///
/// 视觉与交互规范严格对齐参考源码：
/// 1. 顶部 Header (44px)：纯文字标题排版（展开态展示，折叠态平滑淡出，严禁添加左侧 Logo）；
/// 2. 统一折叠切换控件：28x28 圆形热区，展开态靠右留白 20px，折叠态在 72px 内绝对水平居中，带 chevron 180° 旋转过渡；
/// 3. 高亮指示器胶囊：展开态 180x40 圆角 20，折叠态 56x32 圆角 16；
/// 4. 内部图文排版：18x18 图标（展开态左间距 16px、图文间距 14px，折叠态在胶囊内严格居中）；
/// 5. 底部设置按钮：严格固定于左下角（bottomMargin: 16px）。
class DesktopNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final bool extended;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onToggle;
  final List<DesktopNavDestination> destinations;

  const DesktopNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.extended,
    required this.onDestinationSelected,
    required this.onToggle,
    required this.destinations,
  });

  bool get isCollapsed => !extended;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;
    final railWidth = isCollapsed ? 72.0 : 220.0;

    // 前 N-1 项为常规导航项，最后一项固定为底部的设置项
    final mainDestinations = destinations.length > 1
        ? destinations.sublist(0, destinations.length - 1)
        : destinations;
    final settingsIndex = destinations.length - 1;
    final settingsDest = destinations.length > 1 ? destinations.last : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: railWidth,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(
            color: scheme.borderSubtle,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Section: Header (展开态仅标题+折叠按钮，严禁添加左侧Logo)
          Padding(
            padding: EdgeInsets.only(top: topPadding > 0 ? topPadding + 8 : 16.0),
            child: SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  // 标题（展开态显示，折叠态平滑淡出，严禁添加图标）
                  Positioned(
                    left: 20,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: isCollapsed ? 0.0 : 1.0,
                      child: Text(
                        'Teigi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  // 统一折叠切换控件 (28x28 圆形热区，展开态靠右留白 20px，折叠态在 72px 内绝对水平居中)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    left: isCollapsed ? 22.0 : (220.0 - 28.0 - 20.0),
                    top: (44.0 - 28.0) / 2,
                    child: _SidebarToggleButton(
                      isCollapsed: isCollapsed,
                      onToggle: onToggle,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 2. Middle Navigation Items
          for (var i = 0; i < mainDestinations.length; i++)
            _NavItem(
              dest: mainDestinations[i],
              isSelected: selectedIndex == i,
              isCollapsed: isCollapsed,
              onTap: () => onDestinationSelected(i),
            ),

          const Spacer(),

          // 3. Bottom Settings Button (严格固定左下角，自适应根折叠态，bottomMargin: 16)
          if (settingsDest != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _NavItem(
                dest: settingsDest,
                isSelected: selectedIndex == settingsIndex,
                isCollapsed: isCollapsed,
                onTap: () => onDestinationSelected(settingsIndex),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarToggleButton extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;

  const _SidebarToggleButton({
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  State<_SidebarToggleButton> createState() => _SidebarToggleButtonState();
}

class _SidebarToggleButtonState extends State<_SidebarToggleButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color bg;
    if (_isPressed) {
      bg = scheme.surfaceContainerHighest;
    } else if (_isHovered) {
      bg = scheme.surfaceContainerHigh;
    } else {
      bg = Colors.transparent;
    }

    return Tooltip(
      message: widget.isCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: const Key('sidebar-toggle-btn'),
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onToggle,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: _isPressed ? 0.92 : 1.0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: AnimatedRotation(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  turns: widget.isCollapsed ? 0.5 : 0.0,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: _isHovered ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final DesktopNavDestination dest;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _NavItem({
    required this.dest,
    required this.isSelected,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // 颜色计算
    Color indicatorColor;
    if (widget.isSelected) {
      indicatorColor = scheme.primary;
    } else if (_isHovered) {
      indicatorColor = scheme.surfaceContainerHigh;
    } else {
      indicatorColor = Colors.transparent;
    }

    final fgColor = widget.isSelected
        ? scheme.onPrimary
        : (_isHovered ? scheme.onSurface : scheme.onSurfaceVariant);

    final iconData = widget.isSelected
        ? (widget.dest.selectedIcon ?? widget.dest.icon)
        : widget.dest.icon;

    // 指示器尺寸：展开态 180x40 圆角 20；折叠态 56x32 圆角 16
    final indicatorWidth = widget.isCollapsed ? 56.0 : 180.0;
    final indicatorHeight = widget.isCollapsed ? 32.0 : 40.0;
    final indicatorRadius = widget.isCollapsed ? 16.0 : 20.0;

    return Tooltip(
      message: widget.isCollapsed ? widget.dest.label : '',
      waitDuration: const Duration(milliseconds: 400),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _isPressed ? 0.96 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                width: indicatorWidth,
                height: indicatorHeight,
                decoration: BoxDecoration(
                  color: indicatorColor,
                  borderRadius: BorderRadius.circular(indicatorRadius),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(indicatorRadius),
                  child: widget.isCollapsed
                      ? Center(
                          child: Icon(
                            iconData,
                            size: 18,
                            color: fgColor,
                          ),
                        )
                      : Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(
                              iconData,
                              size: 18,
                              color: fgColor,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 150),
                                opacity: widget.isCollapsed ? 0.0 : 1.0,
                                child: Text(
                                  widget.dest.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: widget.isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: fgColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
