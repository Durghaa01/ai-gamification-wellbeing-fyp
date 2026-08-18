class SmartAlertSystem {
  bool hasActiveAlerts = false;
  List<String> activeAlerts = [];

  void checkRiskThresholds(double riskLevel) {
    activeAlerts.clear();
    if (riskLevel > 0.7) {
      activeAlerts.add(
        "High risk pattern detected - consider immediate check-in",
      );
      hasActiveAlerts = true;
    } else if (riskLevel > 0.5) {
      activeAlerts.add("Moderate risk - monitor closely");
      hasActiveAlerts = true;
    } else {
      hasActiveAlerts = false;
    }
  }

  String getLatestAlert() {
    return activeAlerts.isNotEmpty ? activeAlerts.first : "No active alerts";
  }

  String getAlertDetails() {
    return activeAlerts.isNotEmpty
        ? activeAlerts.join('\n\n')
        : "No risk alerts at this time. All patterns appear normal.";
  }
}
