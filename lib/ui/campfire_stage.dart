/// A milestone earned by the current daily streak in Pixel Valley.
enum CampfireStage {
  smoke(1),
  ember(2),
  spark(3),
  firstFlame(4),
  kindling(5),
  campfire(7),
  hotCoals(10),
  flyingSparks(14),
  kneeHighFlames(21),
  tallFlame(28),
  fireWhirl(35),
  forestEdge(42),
  burningBranches(49),
  blazingTree(60),
  burningTreetops(75),
  ragingForest(90),
  goldenRiver(92),
  horizonLights(94),
  firefall(96),
  flameCrown(98),
  forestHeart(100);

  const CampfireStage(this.day);

  /// First day on which this stage is visible, inclusive.
  final int day;

  static CampfireStage? forDays(int days) {
    for (final stage in values.reversed) {
      if (days >= stage.day) return stage;
    }
    return null;
  }
}
