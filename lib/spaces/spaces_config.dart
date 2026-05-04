import 'package:flutter/material.dart';
import '../app_theme.dart';

class SpaceConfig {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String systemPrompt;
  final List<String> starterPrompts;
  final List<SpaceConfig> children; // for subspaces like Physics, Biology

  const SpaceConfig({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.systemPrompt,
    this.starterPrompts = const [],
    this.children = const [],
  });
}

// quick helper for blue accent chips
Color get spaceTint => AppTheme.electricBlue.withOpacity(.15);

const _genericWriter =
    "You are helpful, concise, and organized. Use bullets, step-by-step actions, "
    "and ask for missing info. Prefer short outputs unless asked.";

const spaces = <SpaceConfig>[
  SpaceConfig(
    id: "social",
    name: "Social",
    icon: Icons.share_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You write catchy social posts with 3 variants and 5 smart hashtags.",
    starterPrompts: [
      "Write a Twitter/X post announcing a product drop.",
      "Instagram caption for beach photo: playful tone.",
      "LinkedIn update about a new role (confident, humble).",
    ],
  ),
  SpaceConfig(
    id: "email",
    name: "Email",
    icon: Icons.email_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You are an email assistant. Provide subject lines and a clear body. "
        "Offer two tones: friendly and formal.",
    starterPrompts: [
      "Follow-up email after client meeting (professional).",
      "Apology email for shipping delay.",
      "Cold outreach to a local cafe—partnership idea.",
    ],
  ),
  SpaceConfig(
    id: "biz",
    name: "Business & Marketing",
    icon: Icons.trending_up_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You produce lean marketing plans, ICPs, and ad copy with A/B options.",
    starterPrompts: [
      "7-day GTM plan for a notes app.",
      "Google Ads headlines (5x) for fitness studio.",
      "Unique value proposition for my service:",
    ],
  ),
  SpaceConfig(
    id: "education",
    name: "Education",
    icon: Icons.school_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You are a patient teacher. Explain with examples and 3-question mini-quiz.",
    children: [
      SpaceConfig(
        id: "physics",
        name: "Physics",
        icon: Icons.auto_graph_rounded,
        color: AppTheme.electricBlue,
        systemPrompt:
            "Physics tutor. Derive formulas step-by-step; show units and quick checks.",
        starterPrompts: ["Explain Newton’s laws with daily examples.",
          "Numerical on projectile motion (work it out)."],
      ),
      SpaceConfig(
        id: "biology",
        name: "Biology",
        icon: Icons.biotech_rounded,
        color: AppTheme.electricBlue,
        systemPrompt:
            "Biology tutor. Use clear diagrams-in-words; compare/contrast tables.",
        starterPrompts: ["Photosynthesis vs respiration (table).",
          "Immune system: innate vs adaptive."],
      ),
      SpaceConfig(
        id: "chemistry",
        name: "Chemistry",
        icon: Icons.science_rounded,
        color: AppTheme.electricBlue,
        systemPrompt:
            "Chemistry tutor. Balance equations; safety notes; real-life links.",
      ),
      SpaceConfig(
        id: "maths",
        name: "Maths",
        icon: Icons.calculate_rounded,
        color: AppTheme.electricBlue,
        systemPrompt:
            "Math tutor. Show solution path first, then final answer; avoid leaps.",
      ),
    ],
    starterPrompts: [
      "Explain photosynthesis like I’m 12.",
      "Practice quiz: kinematics (5 Qs, increasing difficulty).",
    ],
  ),
  SpaceConfig(
    id: "art",
    name: "Art",
    icon: Icons.brush_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You help with creative writing/visual ideas; propose 3 styles.",
  ),
  SpaceConfig(
    id: "astrology",
    name: "Astrology",
    icon: Icons.stars_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You give positive, reflective guidance; avoid absolute predictions.",
  ),
  SpaceConfig(
    id: "travel",
    name: "Travel",
    icon: Icons.flight_takeoff_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You build itineraries with budget, travel time, and must-try spots.",
  ),
  SpaceConfig(
    id: "lifestyle",
    name: "Daily Lifestyle",
    icon: Icons.self_improvement_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You create routines, habit stacks, and tiny action checklists.",
  ),
  SpaceConfig(
    id: "relationship",
    name: "Relationship",
    icon: Icons.favorite_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You suggest empathetic, healthy communication. No medical/therapy claims.",
  ),
  SpaceConfig(
    id: "fun",
    name: "Fun",
    icon: Icons.celebration_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You generate games, jokes, and quick prompts—light and safe.",
  ),
  SpaceConfig(
    id: "career",
    name: "Career",
    icon: Icons.work_rounded,
    color: AppTheme.electricBlue,
    systemPrompt:
        "$_genericWriter You help craft resumes, cover letters, and interview prep with STAR.",
  ),
];
