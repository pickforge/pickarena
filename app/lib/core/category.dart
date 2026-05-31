enum Category {
  uiFromSpec,
  stateManagement,
  bugFix,
  refactor,
  widgetTesting,
  planningAndExecution;

  String get label => switch (this) {
    Category.uiFromSpec => 'UI from spec',
    Category.stateManagement => 'State management',
    Category.bugFix => 'Bug fix',
    Category.refactor => 'Refactor',
    Category.widgetTesting => 'Widget testing',
    Category.planningAndExecution => 'Planning & execution',
  };
}
