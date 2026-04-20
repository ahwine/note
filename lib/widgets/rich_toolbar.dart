import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class RichToolbar extends StatefulWidget {
  final QuillController controller;
  final bool isDark;
  final VoidCallback onImageTap;
  final VoidCallback onDrawTap;
  final VoidCallback onVoiceTap;

  const RichToolbar({
    super.key,
    required this.controller,
    required this.isDark,
    required this.onImageTap,
    required this.onDrawTap,
    required this.onVoiceTap,
  });

  @override
  State<RichToolbar> createState() => _RichToolbarState();
}

class _RichToolbarState extends State<RichToolbar> {
  bool _showFormat = false;

  Color get _iconColor => widget.isDark ? Colors.white70 : Colors.black54;
  Color get _bgColor => widget.isDark ? AppColors.bgDark2 : AppColors.bgLight2;
  Color get _dividerColor =>
      widget.isDark ? AppColors.bgDark3 : AppColors.bgLight3;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  Map<String, Attribute> get _attrs =>
      widget.controller.getSelectionStyle().attributes;

  bool _isInlineStyleActive(Attribute attribute) {
    return _attrs.containsKey(attribute.key);
  }

  bool _isAlignActive(Attribute attribute) {
    return _attrs[Attribute.align.key]?.value == attribute.value;
  }

  bool _isHeadingActive(Attribute attribute) {
    return _attrs[Attribute.header.key]?.value == attribute.value;
  }

  bool _isListActive(Attribute attribute) {
    return _attrs[Attribute.list.key]?.value == attribute.value;
  }

  bool get _isBodyActive {
    return !_attrs.containsKey(Attribute.header.key);
  }

  void _toggleInlineStyle(Attribute attribute) {
    final isActive = _isInlineStyleActive(attribute);
    widget.controller.formatSelection(
      isActive ? Attribute.clone(attribute, null) : attribute,
    );
  }

  void _toggleListStyle(Attribute attribute) {
    final isActive = _isListActive(attribute);

    if (isActive) {
      widget.controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      widget.controller.formatSelection(attribute);
    }

    widget.controller.formatSelection(Attribute.clone(Attribute.color, null));
    widget.controller
        .formatSelection(Attribute.clone(Attribute.background, null));
  }

  void _toggleChecklist() {
    final isActive = _isListActive(Attribute.unchecked);

    if (isActive) {
      widget.controller.formatSelection(Attribute.clone(Attribute.list, null));
    } else {
      widget.controller.formatSelection(Attribute.unchecked);
    }

    widget.controller.formatSelection(Attribute.clone(Attribute.color, null));
    widget.controller
        .formatSelection(Attribute.clone(Attribute.background, null));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _bgColor,
        border: Border(
          top: BorderSide(color: _dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showFormat) _buildFormatToolbar(),
          _buildMainToolbar(),
        ],
      ),
    );
  }

  Widget _buildMainToolbar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: _ToolbarButton(
                icon: Icons.text_format,
                label: 'Aa',
                color: _showFormat ? AppColors.primary : _iconColor,
                onTap: () => setState(() => _showFormat = !_showFormat),
              ),
            ),
            Expanded(
              child: _ToolbarButton(
                icon: Icons.photo_camera_outlined,
                color: _iconColor,
                onTap: widget.onImageTap,
              ),
            ),
            Expanded(
              child: _ToolbarButton(
                icon: Icons.draw_outlined,
                color: _iconColor,
                onTap: widget.onDrawTap,
              ),
            ),
            Expanded(
              child: _ToolbarButton(
                icon: Icons.mic_none_rounded,
                color: _iconColor,
                onTap: widget.onVoiceTap,
              ),
            ),
            Expanded(
              child: _ToolbarButton(
                icon: Icons.check_box_outlined,
                color: _isListActive(Attribute.unchecked)
                    ? AppColors.primary
                    : _iconColor,
                onTap: _toggleChecklist,
              ),
            ),
            Expanded(
              child: _ToolbarButton(
                icon: Icons.keyboard_hide_outlined,
                color: _iconColor,
                onTap: () => FocusScope.of(context).unfocus(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatToolbar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _dividerColor, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                _HeadingButton(
                  label: 'H1',
                  isActive: _isHeadingActive(Attribute.h1),
                  isDark: widget.isDark,
                  onTap: () => widget.controller.formatSelection(Attribute.h1),
                ),
                const SizedBox(width: 8),
                _HeadingButton(
                  label: 'H2',
                  isActive: _isHeadingActive(Attribute.h2),
                  isDark: widget.isDark,
                  onTap: () => widget.controller.formatSelection(Attribute.h2),
                ),
                const SizedBox(width: 8),
                _HeadingButton(
                  label: 'H3',
                  isActive: _isHeadingActive(Attribute.h3),
                  isDark: widget.isDark,
                  onTap: () => widget.controller.formatSelection(Attribute.h3),
                ),
                const SizedBox(width: 8),
                _HeadingButton(
                  label: 'Isi',
                  isActive: _isBodyActive,
                  isDark: widget.isDark,
                  onTap: () => widget.controller
                      .formatSelection(Attribute.clone(Attribute.header, null)),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: Row(
              children: [
                _FormatIconButton(
                  icon: Icons.format_bold,
                  isActive: _isInlineStyleActive(Attribute.bold),
                  iconColor: _iconColor,
                  onTap: () => _toggleInlineStyle(Attribute.bold),
                ),
                _FormatIconButton(
                  icon: Icons.format_italic,
                  isActive: _isInlineStyleActive(Attribute.italic),
                  iconColor: _iconColor,
                  onTap: () => _toggleInlineStyle(Attribute.italic),
                ),
                _FormatIconButton(
                  icon: Icons.format_underline,
                  isActive: _isInlineStyleActive(Attribute.underline),
                  iconColor: _iconColor,
                  onTap: () => _toggleInlineStyle(Attribute.underline),
                ),
                _FormatIconButton(
                  icon: Icons.format_strikethrough,
                  isActive: _isInlineStyleActive(Attribute.strikeThrough),
                  iconColor: _iconColor,
                  onTap: () => _toggleInlineStyle(Attribute.strikeThrough),
                ),
                const SizedBox(width: 8),
                _FormatIconButton(
                  icon: Icons.format_list_bulleted,
                  isActive: _isListActive(Attribute.ul),
                  iconColor: _iconColor,
                  onTap: () => _toggleListStyle(Attribute.ul),
                ),
                _FormatIconButton(
                  icon: Icons.format_list_numbered,
                  isActive: _isListActive(Attribute.ol),
                  iconColor: _iconColor,
                  onTap: () => _toggleListStyle(Attribute.ol),
                ),
                const SizedBox(width: 8),
                _FormatIconButton(
                  icon: Icons.format_align_left,
                  isActive: _isAlignActive(Attribute.leftAlignment),
                  iconColor: _iconColor,
                  onTap: () {
                    if (_isAlignActive(Attribute.leftAlignment)) {
                      widget.controller
                          .formatSelection(Attribute.clone(Attribute.align, null));
                    } else {
                      widget.controller.formatSelection(Attribute.leftAlignment);
                    }
                  },
                ),
                _FormatIconButton(
                  icon: Icons.format_align_center,
                  isActive: _isAlignActive(Attribute.centerAlignment),
                  iconColor: _iconColor,
                  onTap: () {
                    if (_isAlignActive(Attribute.centerAlignment)) {
                      widget.controller
                          .formatSelection(Attribute.clone(Attribute.align, null));
                    } else {
                      widget.controller
                          .formatSelection(Attribute.centerAlignment);
                    }
                  },
                ),
                _FormatIconButton(
                  icon: Icons.format_align_right,
                  isActive: _isAlignActive(Attribute.rightAlignment),
                  iconColor: _iconColor,
                  onTap: () {
                    if (_isAlignActive(Attribute.rightAlignment)) {
                      widget.controller
                          .formatSelection(Attribute.clone(Attribute.align, null));
                    } else {
                      widget.controller.formatSelection(Attribute.rightAlignment);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 46,
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }
}

class _FormatIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color iconColor;
  final VoidCallback onTap;

  const _FormatIconButton({
    required this.icon,
    required this.isActive,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(8),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              )
            : null,
        child: Icon(
          icon,
          size: 20,
          color: isActive ? AppColors.primary : iconColor,
        ),
      ),
    );
  }
}

class _HeadingButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _HeadingButton({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark ? AppColors.bgDark3 : AppColors.bgLight3),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive
                ? Colors.black
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}