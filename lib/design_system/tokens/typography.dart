import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralised text styling so the landing page can stay close to the
/// reference mock without repeating the same font configuration.
class MindWellTypography {
  MindWellTypography._();

  static TextStyle display({Color color = Colors.white}) =>
      GoogleFonts.openSans(
        color: color,
        fontSize: 54,
        fontWeight: FontWeight.w300,
        letterSpacing: 1.5,
      );

  static TextStyle heroSubtitle({Color color = Colors.white}) =>
      GoogleFonts.lato(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w300,
        height: 1.5,
      );

  static TextStyle sectionTitle({Color color = Colors.black}) =>
      GoogleFonts.openSans(
        color: color,
        fontSize: 42,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
      );

  static TextStyle sectionSubtitle({Color color = Colors.black}) =>
      GoogleFonts.openSans(
        color: color,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.35,
      );

  static TextStyle body({Color color = Colors.black}) =>
      GoogleFonts.lato(color: color, fontSize: 16, height: 1.6);

  static TextStyle button({Color color = Colors.black}) => GoogleFonts.openSans(
    color: color,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.8,
  );

  static TextStyle cardTitle({Color color = Colors.black}) =>
      GoogleFonts.openSans(
        color: color,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      );
}
