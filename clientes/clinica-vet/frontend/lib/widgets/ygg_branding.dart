import 'package:flutter/material.dart';

class YggBranding extends StatelessWidget {
  final Color? textColor;
  final double? fontSize;
  final bool showIcon;
  final EdgeInsets? padding;
  
  const YggBranding({
    super.key,
    this.textColor,
    this.fontSize = 11,
    this.showIcon = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.grey.shade600;
    
    return Padding(
      padding: padding ?? const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showIcon) ...[
            Image.asset(
              'assets/images/ygg_icon.png',
              width: 28,
              height: 28,

            ),
            const SizedBox(width: 8),
          ],
          Text(
            'Powered by Ygg',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class YggBrandingLight extends StatelessWidget {
  final double? fontSize;
  final bool showIcon;
  final EdgeInsets? padding;
  
  const YggBrandingLight({
    super.key,
    this.fontSize = 11,
    this.showIcon = true,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return YggBranding(
      textColor: Colors.white.withOpacity(0.8),
      fontSize: fontSize,
      showIcon: showIcon,
      padding: padding,
    );
  }
}