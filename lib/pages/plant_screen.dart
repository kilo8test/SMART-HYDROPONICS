import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

// Data model for plant metrics
class PlantMetric {
  final String title;
  final String value;
  final String statusLabel;
  final Color statusColor;
  final IconData bgIcon;
  final Color startColor;
  final Color endColor;
  final double progress;
  final IconData? directionIcon; // For TDS directional indicators
  final Color? iconColor; // For TDS directional icon colors

  const PlantMetric({
    required this.title,
    required this.value,
    required this.statusLabel,
    required this.statusColor,
    required this.bgIcon,
    required this.startColor,
    required this.endColor,
    required this.progress,
    this.directionIcon,
    this.iconColor,
  });
}

// Plant growth stages
class PlantStage {
  final int level;
  final String name;
  final IconData currentIcon;
  final IconData nextIcon;
  final Color stageColor;

  const PlantStage({
    required this.level,
    required this.name,
    required this.currentIcon,
    required this.nextIcon,
    required this.stageColor,
  });
}

class PlantScreen extends StatefulWidget {
  const PlantScreen({super.key});

  @override
  State<PlantScreen> createState() => _PlantScreenState();
}

class _PlantScreenState extends State<PlantScreen> with SingleTickerProviderStateMixin {
  // Available metrics
  late List<PlantMetric> _metrics;
  PlantMetric? _selectedMetric;

  // Fixed Plant Health metric for the progress bar
  late final PlantMetric _plantHealthMetric;

  // Plant growth system
  late final List<PlantStage> _plantStages;
  static const int currentStage = 1; // Current plant stage (1-4)
  static const double levelProgress = 0.95; // Progress within current stage (0-1) - Set to 95% to trigger two-tone effect

  // Sensor and Pump Status
  bool _waterLevelDetected = false;
  bool _pumpStatus = false;
  double _tdsValue = 0.0;
  bool _nutrientAStatus = false;
  bool _nutrientBStatus = false;
  bool _phUpStatus = false;
  bool _phDownStatus = false;

  bool _cameraOnline = false; // Independent camera status - set offline until ESP32 calibrated
  Timer? _refreshTimer;
  bool _isLoading = true;

  // Loading states for controls
  bool _isPumpLoading = false;
  bool _isTdsDosing = false; // TDS dosing in progress
  bool _isPhAdjusting = false; // pH adjustment in progress

  // Animation
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Consistent pump button colors
  final Color _pumpOnColor = Colors.green[800]!;
  // Theme-specific OFF colors
  final Color _waterPumpOffColor = const Color(0xFF90E0EF); // Light Blue/Cyan
  final Color _nutrientPumpOffColor = Colors.orange[200]!; // Light Orange
  final Color _phPumpOffColor = Colors.pink[200]!; // Light Pink

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _initializeMetrics();
    _fetchLatestSensorData();
    // Auto refresh every 1 second
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _fetchLatestSensorData();
    });

    // Initialize slide animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start off-screen right
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
  }

  void _checkAuth() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // Not authenticated, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushNamedAndRemoveUntil('/auth/login', (route) => false);
      });
    }

    // Subscribe to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        // User signed out, redirect to login
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/auth/login', (route) => false);
        }
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _fetchLatestSensorData() async {
    try {
      final response = await Supabase.instance.client
          .from('pump_sensors')
          .select('date_time, tds_value, water_status, water_pump, ph_up, ph_down, nutrient_a, nutrient_b')
          .order('date_time', ascending: false)
          .limit(1)
          .single();

      if (!mounted) return;

      setState(() {
        _waterLevelDetected = response['water_status'] ?? false;
        _pumpStatus = response['water_pump'] ?? false;
        _tdsValue = (response['tds_value'] ?? 0.0).toDouble();
        _phUpStatus = response['ph_up'] ?? false;
        _phDownStatus = response['ph_down'] ?? false;
        _nutrientAStatus = response['nutrient_a'] ?? false;
        _nutrientBStatus = response['nutrient_b'] ?? false;
        _isLoading = false;
      });

      _updateWaterMetric();
      _updateEsp32CameraMetric();
      _updateTdsMetric();
      _updatePhMetric();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // On error, still update metrics to show default/error state
        _updateWaterMetric();
        _updateEsp32CameraMetric();
        _updateTdsMetric();
        _updatePhMetric();
      });
    }
  }

  /// Helper to show a consistent warning when no water is detected.
  void _showNoWaterWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: Colors.white),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Cannot activate pump: No water detected',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Control main water pump status
  Future<void> _controlPump(bool turnOn) async {
    if (_isPumpLoading) return;
    if (!_waterLevelDetected) {
      _showNoWaterWarning();
      return;
    }

    setState(() => _isPumpLoading = true);

    try {
      debugPrint('🎮 Flutter: Updating main water pump status, turnOn=$turnOn');

      final latest = await Supabase.instance.client
          .from('pump_sensors')
          .select('id')
          .order('date_time', ascending: false)
          .limit(1)
          .single();
      final id = latest['id'];

      await Supabase.instance.client
          .from('pump_sensors')
          .update({'water_pump': turnOn})
          .eq('id', id);

      if (!mounted) return;
      setState(() => _pumpStatus = turnOn); // Optimistic update

      await Future.delayed(const Duration(seconds: 1));
      _fetchLatestSensorData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            turnOn ? 'Main pump ACTIVATED - Water flowing!' : 'Main pump DEACTIVATED - Flow stopped',
          ),
          backgroundColor: turnOn ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('❌ Flutter: Main pump control failed: $e');
    } finally {
      if(mounted) setState(() => _isPumpLoading = false);
    }
  }

  /// Toggles Nutrient A or B pump with mutual exclusivity.
  Future<void> _toggleNutrientPump(String pumpId) async {
    if (_isTdsDosing) return;
    if (!_waterLevelDetected) {
      _showNoWaterWarning();
      return;
    }

    setState(() => _isTdsDosing = true);

    try {
      final bool isPumpA = pumpId == 'A';
      final targetPumpOn = isPumpA ? !_nutrientAStatus : !_nutrientBStatus;

      Map<String, bool> updatePayload;
      if (targetPumpOn) {
        // Turning a pump ON, ensure the other is OFF.
        updatePayload = {'nutrient_a': isPumpA, 'nutrient_b': !isPumpA};
      } else {
        // Turning a pump OFF, don't affect the other.
        updatePayload = {if (isPumpA) 'nutrient_a': false else 'nutrient_b': false};
      }

      debugPrint('🧪 Flutter: Toggling nutrient pump. ID: $pumpId, payload: $updatePayload');

      final latest = await Supabase.instance.client.from('pump_sensors').select('id').order('date_time', ascending: false).limit(1).single();
      await Supabase.instance.client.from('pump_sensors').update(updatePayload).eq('id', latest['id']);

      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 1));
      _fetchLatestSensorData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(targetPumpOn ? 'Nutrient $pumpId pump ACTIVATED' : 'Nutrient $pumpId pump DEACTIVATED'),
          backgroundColor: targetPumpOn ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('❌ Flutter: Nutrient dosing failed: $e');
    } finally {
      if (mounted) setState(() => _isTdsDosing = false);
    }
  }

  /// Toggles pH Up or Down pump with mutual exclusivity.
  Future<void> _togglePhPump(bool isUp) async {
    if (_isPhAdjusting) return;
    if (!_waterLevelDetected) {
      _showNoWaterWarning();
      return;
    }

    setState(() => _isPhAdjusting = true);

    try {
      final targetPumpOn = isUp ? !_phUpStatus : !_phDownStatus;

      Map<String, bool> updatePayload;
      if (targetPumpOn) {
        // Turning a pump ON, ensure the other is OFF.
        updatePayload = {'ph_up': isUp, 'ph_down': !isUp};
      } else {
        // Turning a pump OFF, don't affect the other.
        updatePayload = {if (isUp) 'ph_up': false else 'ph_down': false};
      }

      debugPrint('🧪 Flutter: Toggling pH pump. isUp: $isUp, payload: $updatePayload');

      final latest = await Supabase.instance.client.from('pump_sensors').select('id').order('date_time', ascending: false).limit(1).single();
      await Supabase.instance.client.from('pump_sensors').update(updatePayload).eq('id', latest['id']);

      if (!mounted) return;
      await Future.delayed(const Duration(seconds: 1));
      _fetchLatestSensorData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(targetPumpOn ? 'pH ${isUp ? 'UP' : 'DOWN'} pump ACTIVATED' : 'pH ${isUp ? 'UP' : 'DOWN'} pump DEACTIVATED'),
          backgroundColor: targetPumpOn ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      debugPrint('❌ Flutter: pH adjustment failed: $e');
    } finally {
      if (mounted) setState(() => _isPhAdjusting = false);
    }
  }

  void _updateWaterMetric() {
    final waterMetric = PlantMetric(
      title: 'Water Level',
      value: _isLoading ? 'Loading...' : (_waterLevelDetected ? 'DETECTED' : 'EMPTY'),
      statusLabel: _isLoading ? 'Loading...' : (_waterLevelDetected ? 'Normal' : 'Empty'),
      statusColor: _isLoading ? Colors.grey : (_waterLevelDetected ? const Color(0xFF16A34A) : const Color(0xFFEF4444)),  // Green for detected, Red for empty
      bgIcon: Icons.water_drop,
      startColor: _isLoading ? Colors.grey : (_waterLevelDetected ? const Color(0xFF00B4D8) : Colors.grey[400]!),  // Blue for detected, Gray for empty
      endColor: _isLoading ? Colors.grey : (_waterLevelDetected ? const Color(0xFF48CAE4) : Colors.grey[600]!),    // Blue for detected, Darker gray for empty
      progress: _waterLevelDetected ? 1.0 : 0.0,
    );

    // Find and update the water metric
    final int waterIndex = _metrics.indexWhere((m) => m.title == 'Water Level');
    if (waterIndex != -1) {
      setState(() {
        _metrics[waterIndex] = waterMetric;
        if (_selectedMetric?.title == 'Water Level') {
          _selectedMetric = waterMetric;
        }
      });
    }
  }

  void _updateEsp32CameraMetric() {
    final cameraMetric = PlantMetric(
      title: 'Actual Footage',
      value: _cameraOnline ? 'ONLINE' : 'OFFLINE',
      statusLabel: '',
      statusColor: _cameraOnline ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
      bgIcon: _cameraOnline ? Icons.videocam : Icons.videocam_off,
      startColor: const Color(0xFF80ED99),
      endColor: const Color(0xFF57CC99),
      progress: 0.0,
    );

    // Find and update the ESP32 Camera metric
    final int cameraIndex = _metrics.indexWhere((m) => m.title == 'Actual Footage');
    if (cameraIndex != -1) {
      setState(() {
        _metrics[cameraIndex] = cameraMetric;
        if (_selectedMetric?.title == 'Actual Footage') {
          _selectedMetric = cameraMetric;
        }
      });
    }
  }

  void _updateTdsMetric() {
    // TDS optimal range for hydroponics: 400-1200 ppm
    // Determine status for directional icons
    String statusLabel;
    Color statusColor;
    IconData directionIcon;
    Color iconColor;

    if (_tdsValue < 400) {
      statusLabel = 'Low';
      statusColor = const Color(0xFFF59E0B); // Orange background
      directionIcon = Icons.arrow_downward; // Red down arrow
      iconColor = const Color(0xFFEF4444); // Red for both icon and value
    } else if (_tdsValue >= 400 && _tdsValue <= 1200) {
      statusLabel = 'Optimal';
      statusColor = const Color(0xFF16A34A); // Green background
      directionIcon = Icons.remove; // Green minus
      iconColor = const Color(0xFF16A34A); // Green for both icon and value
    } else {
      statusLabel = 'High';
      statusColor = const Color(0xFFF59E0B); // Orange background
      directionIcon = Icons.arrow_upward; // Yellow up arrow
      iconColor = const Color(0xFFF59E0B); // Yellow for both icon and value
    }

    final tdsMetric = PlantMetric(
      title: 'Nutrient Level',
      value: _isLoading ? 'Loading...' : _tdsValue.toStringAsFixed(3), // Full decimal precision
      statusLabel: _isLoading ? 'Loading...' : statusLabel,
      statusColor: _isLoading ? Colors.grey : statusColor,
      bgIcon: Icons.biotech,
      startColor: _isLoading ? Colors.grey : const Color(0xFFFDE68A),
      endColor: _isLoading ? Colors.grey : const Color(0xFFF59E0B),
      progress: 0.0, // Not used for TDS display
      directionIcon: directionIcon, // New field for directional icon
      iconColor: iconColor, // New field for icon color
    );

    // Find and update the TDS metric
    final int tdsIndex = _metrics.indexWhere((m) => m.title == 'Nutrient Level');
    if (tdsIndex != -1) {
      setState(() {
        _metrics[tdsIndex] = tdsMetric;
        if (_selectedMetric?.title == 'Nutrient Level') {
          _selectedMetric = tdsMetric;
        }
      });
    }
  }

  void _updatePhMetric() {
    // pH optimal range for hydroponics: 5.5-6.5
    // For now, display 0.0 as placeholder until sensor is connected
    const double phValue = 0.0; // Placeholder

    // Since no sensor yet, show neutral/unknown status
    const statusLabel = 'Unknown';
    const statusColor = Colors.grey;
    const directionIcon = Icons.remove; // Neutral minus
    const iconColor = Colors.grey;

    final phMetric = PlantMetric(
      title: 'pH Level',
      value: _isLoading ? 'Loading...' : phValue.toStringAsFixed(1), // One decimal place for pH
      statusLabel: _isLoading ? 'Loading...' : statusLabel,
      statusColor: _isLoading ? Colors.grey : statusColor,
      bgIcon: Icons.speed,
      startColor: _isLoading ? Colors.grey : const Color(0xFFFFAFCC),
      endColor: _isLoading ? Colors.grey : const Color(0xFFFFC8DD),
      progress: 0.0, // Not used for pH display
      directionIcon: directionIcon,
      iconColor: iconColor,
    );

    // Find and update the pH metric
    final int phIndex = _metrics.indexWhere((m) => m.title == 'pH Level');
    if (phIndex != -1) {
      setState(() {
        _metrics[phIndex] = phMetric;
        if (_selectedMetric?.title == 'pH Level') {
          _selectedMetric = phMetric;
        }
      });
    }
  }

  void _initializeMetrics() {
    // Initialize fixed Plant Health metric for progress bar
    _plantHealthMetric = const PlantMetric(
      title: 'Plant Health',
      value: '86%',
      statusLabel: 'Excellent',
      statusColor: Color(0xFF16A34A),
      bgIcon: Icons.local_florist,
      startColor: Color(0xFF80ED99),
      endColor: Color(0xFF57CC99),
      progress: 0.86,
    );

    _metrics = [
      PlantMetric(
        title: 'Actual Footage',
        value: _cameraOnline ? 'ONLINE' : 'OFFLINE',
        statusLabel: '',
        statusColor: _cameraOnline ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
        bgIcon: _cameraOnline ? Icons.videocam : Icons.videocam_off,
        startColor: const Color(0xFF80ED99),
        endColor: const Color(0xFF57CC99),
        progress: 0.0,
      ),
      PlantMetric(
        title: 'Water Level',
        value: 'Loading...',
        statusLabel: '',  // Removed status label
        statusColor: Colors.grey,
        bgIcon: Icons.water_drop,
        startColor: Colors.grey,
        endColor: Colors.grey,
        progress: 0.0,
      ),
      PlantMetric(
        title: 'pH Level',
        value: '0.0', // Placeholder until sensor is connected
        statusLabel: 'Unknown',
        statusColor: Colors.grey,
        bgIcon: Icons.speed,
        startColor: const Color(0xFFFFAFCC),
        endColor: const Color(0xFFFFC8DD),
        progress: 0.0,
        directionIcon: Icons.remove, // Default to neutral
        iconColor: Colors.grey,
      ),
      PlantMetric(
        title: 'Nutrient Level',
        value: 'Loading...',
        statusLabel: 'Loading...',
        statusColor: Colors.grey,
        bgIcon: Icons.biotech,
        startColor: Colors.grey,
        endColor: Colors.grey,
        progress: 0.0,
      ),
    ];

    _plantStages = [
      const PlantStage(
        level: 1,
        name: 'Seed',
        currentIcon: Icons.grain, // Plant seed icon
        nextIcon: Icons.spa, // Seed with roots (sprout)
        stageColor: Color(0xFF8B5CF6),
      ),
      const PlantStage(
        level: 2,
        name: 'Sprout',
        currentIcon: Icons.spa, // Seed with roots
        nextIcon: Icons.grass, // Small plant
        stageColor: Color(0xFF06B6D4),
      ),
      const PlantStage(
        level: 3,
        name: 'Growth',
        currentIcon: Icons.grass, // Plant
        nextIcon: Icons.local_florist, // Big plant
        stageColor: Color(0xFF10B981),
      ),
      const PlantStage(
        level: 4,
        name: 'Harvest',
        currentIcon: Icons.local_florist, // Big plant ready to harvest
        nextIcon: Icons.celebration, // Harvest celebration
        stageColor: Color(0xFFF59E0B),
      ),
    ];

    // No default selection - start with normal view
    _selectedMetric = null;
  }

  void _onMetricSelected(PlantMetric metric) {
    setState(() {
      _selectedMetric = metric;

      // Handle sliding animation
      if (metric.title == 'Actual Footage') {
        // Slide to camera view (right to left)
        _slideController.forward();
      } else {
        // Return to normal view (left to right)
        _slideController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Plant Center', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background gradient to match the app's aesthetic
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE9FFF4), Color(0xFFBFF3D8), Color(0xFF77D9AA)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox.expand(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 720),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const double spacing = 16;
                            const int columns = 2;
                            final double tileWidth = (constraints.maxWidth - spacing) / columns;

                            return Wrap(
                              spacing: spacing,
                              runSpacing: spacing,
                              alignment: WrapAlignment.center,
                              children: _metrics.map((metric) {
                                return SizedBox(
                                  width: tileWidth,
                                  child: _InfoSquare(
                                    metric: metric,
                                    isSelected: _selectedMetric == metric,
                                    onTap: () => _onMetricSelected(metric),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ),
                    ),
                    // Quick Action Buttons or Camera
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: SizedBox(
                        height: 240,
                        child: Stack(
                          children: [
                            // Buttons for other metrics
                            if (_selectedMetric?.title != 'Actual Footage')
                              if (_selectedMetric?.title == 'Water Level')
                                Center(
                                  child: _QuickActionButton(
                                    icon: Icons.water_drop,
                                    color: _isPumpLoading ? Colors.grey : (_pumpStatus ? _pumpOnColor : _waterPumpOffColor),
                                    onTap: () => _controlPump(!_pumpStatus),
                                    isLoading: _isPumpLoading,
                                  ),
                                )
                              else if (_selectedMetric?.title == 'Nutrient Level')
                                Center(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Nutrient A Button
                                      _TdsDosingButton(
                                        child: Text('A', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))])),
                                        color: _isTdsDosing ? Colors.grey : (_nutrientAStatus ? _pumpOnColor : _nutrientPumpOffColor),
                                        onTap: _isTdsDosing ? null : () => _toggleNutrientPump('A'),
                                        isLoading: _isTdsDosing,
                                      ),
                                      const SizedBox(width: 20),
                                      // Nutrient B Button
                                      _TdsDosingButton(
                                        child: Text('B', style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))])),
                                        color: _isTdsDosing ? Colors.grey : (_nutrientBStatus ? _pumpOnColor : _nutrientPumpOffColor),
                                        onTap: _isTdsDosing ? null : () => _toggleNutrientPump('B'),
                                        isLoading: _isTdsDosing,
                                      ),
                                    ],
                                  ),
                                )
                              else if (_selectedMetric?.title == 'pH Level')
                                  Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Decrease pH Button (pH Down)
                                        _TdsDosingButton(
                                          child: Icon(Icons.arrow_downward, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
                                          color: _isPhAdjusting ? Colors.grey : (_phDownStatus ? _pumpOnColor : _phPumpOffColor),
                                          onTap: _isPhAdjusting ? null : () => _togglePhPump(false), // isUp = false
                                          isLoading: _isPhAdjusting,
                                        ),
                                        const SizedBox(width: 20),
                                        // Increase pH Button (pH Up)
                                        _TdsDosingButton(
                                          child: Icon(Icons.arrow_upward, color: Colors.white, size: 28, shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))]),
                                          color: _isPhAdjusting ? Colors.grey : (_phUpStatus ? _pumpOnColor : _phPumpOffColor),
                                          onTap: _isPhAdjusting ? null : () => _togglePhPump(true), // isUp = true
                                          isLoading: _isPhAdjusting,
                                        ),
                                      ],
                                    ),
                                  ),
                            // Camera sliding in
                            SlideTransition(
                              position: _slideAnimation,
                              child: _CameraView(cameraOnline: _cameraOnline),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Plants always visible
                    Column(
                      children: [
                        // Enhanced Plant Health Progress Bar with Growth Stages
                        Container(
                          margin: const EdgeInsets.only(bottom: 135), // Easy spacing control
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Enhanced Progress Bar with Plant Stages (no text display)
                              _PlantGrowthProgressBar(
                                plantHealthMetric: _plantHealthMetric,
                                currentStage: _plantStages[currentStage - 1],
                                nextStage: currentStage < _plantStages.length
                                    ? _plantStages[currentStage]
                                    : _plantStages.last,
                                levelProgress: levelProgress,
                                currentStageLevel: currentStage,
                              ),
                            ],
                          ),
                        ),
                        // Replace previous divider with glossy divider with center hole
                        const GlossyDivider(height: 125.0),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSquare extends StatelessWidget {
  const _InfoSquare({
    required this.metric,
    required this.isSelected,
    required this.onTap,
  });

  final PlantMetric metric;
  final bool isSelected;
  final VoidCallback onTap;

  Color _statusToColor(BuildContext context) {
    final String label = metric.statusLabel.toLowerCase().trim();
    if (label.contains('poor') || label.contains('critical') || label.contains('low')) {
      return const Color(0xFFEF4444); // red
    }
    if (label.contains('warn') || label.contains('caution') || label.contains('medium')) {
      return const Color(0xFFF59E0B); // yellow/amber
    }
    if (label.contains('excellent') || label.contains('normal') || label.contains('good') || label.contains('optimal') || label.contains('ok')) {
      return const Color(0xFF16A34A); // green
    }
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    final Color computedStatusColor = _statusToColor(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: metric.title == 'Water Level'
                ? [
              metric.value == 'DETECTED'
                  ? const Color(0xFF00B4D8)  // Bright blue for detected
                  : Colors.grey[400]!,       // Light gray for empty
              metric.value == 'DETECTED'
                  ? const Color(0xFF48CAE4)  // Light blue for detected
                  : Colors.grey[600]!,       // Dark gray for empty
            ]
                : metric.title == 'Actual Footage'
                ? [
              metric.value == 'ONLINE'
                  ? const Color(0xFF80ED99)  // Green for online
                  : Colors.grey[400]!,       // Gray for offline
              metric.value == 'ONLINE'
                  ? const Color(0xFF57CC99)  // Dark green for online
                  : Colors.grey[600]!,       // Dark gray for offline
            ]
                : [metric.startColor, metric.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            // Primary color glow
            BoxShadow(
              color: metric.endColor.withOpacity(0.35),
              blurRadius: 22,
              offset: const Offset(0, 10),
              spreadRadius: 1,
            ),
            // Secondary color glow
            BoxShadow(
              color: metric.startColor.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 14),
              spreadRadius: 2,
            ),
            // White highlight shadow
            BoxShadow(
              color: Colors.white.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(-3, -3),
              spreadRadius: 1,
            ),
            // Deep shadow for depth
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 28,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
            // Selection indicator
            if (isSelected)
              BoxShadow(
                color: Colors.white.withOpacity(0.6),
                blurRadius: 0,
                spreadRadius: 2,
              ),
          ],
          border: Border.all(
            color: isSelected
                ? Colors.white.withOpacity(0.9)
                : Colors.white.withOpacity(0.6),
            width: isSelected ? 3.0 : 2.0,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background watermark icon
            Positioned(
              right: -6,
              bottom: -6,
              child: Icon(
                metric.bgIcon,
                size: 84,
                color: Colors.white.withOpacity(0.14),
              ),
            ),
            // Inner radial highlight overlay (premium gloss)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topLeft,
                      radius: 1.0,
                      colors: [
                        Colors.white.withOpacity(0.35),
                        Colors.white.withOpacity(0.20),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    metric.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (metric.title == 'Nutrient Level' || metric.title == 'pH Level') ...[
                              // TDS and pH special display: directional icon instead of progress bar
                              if (metric.directionIcon != null)
                                Icon(
                                  metric.directionIcon,
                                  color: metric.iconColor ?? computedStatusColor,
                                  size: 24,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                            ] else if (metric.title != 'Water Level' && metric.title != 'ESP32 Camera' && metric.title != 'Actual Footage') ...[
                              Text(
                                metric.statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  color: computedStatusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.18),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              _MiniProgressBar(
                                progress: metric.progress,
                                backgroundColor: Colors.white.withOpacity(0.20),
                                fillColor: computedStatusColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        metric.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: (metric.title == 'Nutrient Level' || metric.title == 'pH Level')
                              ? (metric.iconColor ?? computedStatusColor) // TDS and pH use iconColor for value
                              : metric.title == 'Water Level'
                              ? (metric.value == 'DETECTED' ? const Color(0xFF16A34A) : const Color(0xFFEF4444))
                              : metric.title == 'Actual Footage'
                              ? metric.statusColor // Use statusColor for actual footage
                              : computedStatusColor,
                          fontSize: (metric.title == 'Water Level' || metric.title == 'Actual Footage') ? 22 : 26,  // Smaller for water level and actual footage
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CameraView extends StatelessWidget {
  const _CameraView({required this.cameraOnline});

  final bool cameraOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Camera image display
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: cameraOnline
                            ? [const Color(0xFF1a1a2e), const Color(0xFF16213e), const Color(0xFF0f3460)]
                            : [const Color(0xFF2d1b1b), const Color(0xFF1a0f0f), const Color(0xFF0d0707)],
                      ),
                    ),
                  ),
                  // Camera image - always available
                  Center(
                    child: Image.asset(
                      'assets/images/lettuce_una.png', // Default camera image
                      fit: BoxFit.contain,
                      width: 200,
                      height: 150,
                    ),
                  ),
                  // Overlay message for offline/calibration
                  if (!cameraOnline)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.build,
                                color: Colors.white,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'ESP32 Camera Not Calibrated',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Camera setup in progress.\nCheck back later.',
                                style: GoogleFonts.inter(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // Camera overlay elements
                  if (cameraOnline) ...[
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Colors.white,
                              size: 8,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'REC',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'ESP32-CAM Live Feed',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniProgressBar extends StatelessWidget {
  const _MiniProgressBar({
    required this.progress,
    required this.backgroundColor,
    required this.fillColor,
  });

  final double progress; // 0..1
  final Color backgroundColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        children: [
          Container(height: 6, color: backgroundColor),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(height: 6, color: fillColor),
          ),
        ],
      ),
    );
  }
}

class GlossyDivider extends StatefulWidget {
  const GlossyDivider({super.key, this.height = 125.0});

  final double height;

  @override
  State<GlossyDivider> createState() => _GlossyDividerState();
}

class _GlossyDividerState extends State<GlossyDivider> with SingleTickerProviderStateMixin {
  ui.Image? _holeImage;
  ui.Image? _lettuceImage;

  late AnimationController _floatController;
  late Animation<double> _float;

  late AnimationController _waveController;
  late Animation<double> _wavePhase;

  // Remove bubble controller, use timer instead
  late Timer _bubbleTimer;
  double _bubbleTime = 0.0; // continuous time in seconds

  @override
  void initState() {
    super.initState();
    _loadHoleImage();
    _loadLettuceImage();

    // Float (up/down) loops forever with reverse
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _float = Tween<double>(begin: -6, end: 6)
        .animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    // Waves (phase 0..2π) loop forever
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
    _wavePhase = Tween<double>(begin: 0.0, end: math.pi * 2)
        .animate(CurvedAnimation(parent: _waveController, curve: Curves.linear));

    // Bubbles: continuous timer (no duration, no reset)
    _bubbleTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (mounted) {
        setState(() {
          _bubbleTime += 0.016; // ~60fps
        });
      }
    });
  }

  Future<void> _loadHoleImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/hole.png');
      final Uint8List bytes = data.buffer.asUint8List();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        if (mounted) setState(() => _holeImage = img);
      });
    } catch (_) {}
  }

  Future<void> _loadLettuceImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/images/lettuce_pangapat.png');
      final Uint8List bytes = data.buffer.asUint8List();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        if (mounted) setState(() => _lettuceImage = img);
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _floatController.dispose();
    _waveController.dispose();
    _bubbleTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GlossyDividerPainter(
          strokeWidth: 10.0,
          holeImage: _holeImage,
          lettuceImage: _lettuceImage,
          float: _float,
          wave: _wavePhase,
          bubbleTime: _bubbleTime, // Pass continuous time instead of phase
        ),
      ),
    );
  }
}

class _GlossyDividerPainter extends CustomPainter {
  _GlossyDividerPainter({
    required this.strokeWidth,
    required this.holeImage,
    required this.lettuceImage,
    required this.float,
    required this.wave,
    required this.bubbleTime,
  }) : super(repaint: Listenable.merge([float, wave]));

  final double strokeWidth;
  final ui.Image? holeImage;
  final ui.Image? lettuceImage;
  final Animation<double>? float;
  final Animation<double>? wave;
  final double bubbleTime;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    // Background gradient
    final Paint bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [Color(0x80FFFFFF), Color(0x47FFFFFF), Color(0x1AFFFFFF)],
        stops: [0.0, 0.5, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, bgPaint);

    // Water with submerged bubbles
    _drawWaterAndBubbles(canvas, size, wave?.value ?? 0.0, bubbleTime);

    // Stroke with center gap
    final double rawGap = size.width * 0.22;
    final double gapWidth = rawGap.clamp(48.0, 180.0);
    final double leftEnd = (size.width - gapWidth) / 2.0;
    final double rightStart = leftEnd + gapWidth;

    final Paint baseTopRectPaint = Paint()..color = const Color(0xCCFFFFFF);
    final Rect topLeftRect = Rect.fromLTWH(0, 0, leftEnd, strokeWidth);
    final Rect topRightRect = Rect.fromLTWH(rightStart, 0, size.width - rightStart, strokeWidth);
    canvas.drawRect(topLeftRect, baseTopRectPaint);
    canvas.drawRect(topRightRect, baseTopRectPaint);

    final double baseY = strokeWidth / 2;

    final Paint blurStroke1 = Paint()
      ..color = const Color(0x55FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawLine(Offset(0, baseY), Offset(leftEnd, baseY), blurStroke1);
    canvas.drawLine(Offset(rightStart, baseY), Offset(size.width, baseY), blurStroke1);

    final Paint midRounded = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.85
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, baseY), Offset(leftEnd, baseY), midRounded);
    canvas.drawLine(Offset(rightStart, baseY), Offset(size.width, baseY), midRounded);

    final Paint blurStroke2 = Paint()
      ..color = const Color(0x88FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawLine(Offset(0, baseY), Offset(leftEnd, baseY), blurStroke2);
    canvas.drawLine(Offset(rightStart, baseY), Offset(size.width, baseY), blurStroke2);

    // Images (hole fixed, lettuce floats in front)
    final double desiredWidth = math.min(360.0, size.width * 0.70);
    final double holeAspect = holeImage != null ? (holeImage!.width / holeImage!.height) : 1.0;
    final double drawWidth = desiredWidth;
    final double drawHeight = drawWidth / holeAspect;

    final Rect dstHole = Rect.fromCenter(
      center: Offset(size.width / 2, baseY),
      width: drawWidth,
      height: drawHeight,
    );

    final double yFloat = baseY + (float?.value ?? 0.0);
    final Rect dstLettuce = Rect.fromCenter(
      center: Offset(size.width / 2, yFloat),
      width: drawWidth,
      height: drawHeight,
    );

    if (holeImage != null) {
      final Rect srcH = Rect.fromLTWH(0, 0, holeImage!.width.toDouble(), holeImage!.height.toDouble());
      canvas.drawImageRect(holeImage!, srcH, dstHole, Paint()..filterQuality = FilterQuality.high);
    }
    if (lettuceImage != null) {
      final Rect srcL = Rect.fromLTWH(0, 0, lettuceImage!.width.toDouble(), lettuceImage!.height.toDouble());
      canvas.drawImageRect(lettuceImage!, srcL, dstLettuce, Paint()..filterQuality = FilterQuality.high);
    }

    // Gleams/bloom
    final Paint gleam1 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x2FFFFFFF), Color(0x14FFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 0.15, 0.45],
      ).createShader(bounds);
    canvas.drawRect(bounds, gleam1);

    final Paint gleam2 = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [Color(0x1FFFFFFF), Color(0x00FFFFFF)],
        stops: [0.0, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, gleam2);

    final Paint bloom = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 0.9,
        colors: [const Color(0x33FFFFFF), const Color(0x00FFFFFF)],
        stops: const [0.0, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, bloom);
  }

  // Water + bubbles + TWO-TONE layers
  void _drawWaterAndBubbles(Canvas canvas, Size size, double wavePhase, double bubbleTimeSec) {
    final double baseY = strokeWidth * 1.8;

    Path buildWave(double amplitude1, double amplitude2, double wavelength1, double wavelength2, double phaseShift) {
      final double k1 = 2 * math.pi / wavelength1;
      final double k2 = 2 * math.pi / wavelength2;

      final Path path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 2.0) {
        final double y1 = baseY + amplitude1 * math.sin(k1 * x + wavePhase + phaseShift);
        final double y2 = baseY + amplitude2 * math.sin(k2 * x + wavePhase + math.pi / 2 + phaseShift);
        final double ySurface = math.min(y1, y2);
        path.lineTo(x, ySurface);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      return path;
    }

    // --- MAIN WAVE (light cyan → cyan → light cyan) ---
    final Path waveMain = buildWave(6.0, 3.5, size.width * 0.8, size.width * 0.5, 0);
    final Paint mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF0077B6).withOpacity(0.7), // deep
          const Color(0xFF00B4D8).withOpacity(0.75), // cyan
          const Color(0xFF90E0EF).withOpacity(0.7), // light cyan
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, baseY, size.width, size.height));
    canvas.drawPath(waveMain, mainPaint);

    // --- SECONDARY WAVE (deep → cyan → light cyan) ---
    final Path waveSecondary = buildWave(8.0, 4.0, size.width * 0.9, size.width * 0.55, math.pi / 2);
    final Paint secondaryPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00B4D8).withOpacity(0.7), // cyan
          const Color(0xFF00B4D8).withOpacity(0.7), // cyan
          const Color(0xFF90E0EF).withOpacity(0.55), // light cyan
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, baseY, size.width, size.height));
    canvas.drawPath(waveSecondary, secondaryPaint);

    // Clip with main path for bubbles
    canvas.save();
    canvas.clipPath(waveMain);

    final Paint bubblePaint = Paint()..style = PaintingStyle.fill;
    final Paint highlightPaint = Paint()..color = const Color(0x66FFFFFF);

    const int bubbleCount = 18;
    for (int i = 0; i < bubbleCount; i++) {
      final double rColor = _rand01(i, 0.11);
      final bool isPH = rColor < 0.5;
      final bool altTone = _rand01(i, 0.12) < 0.5;
      final Color color = isPH
          ? (altTone ? const Color(0xFFFFC8DD) : const Color(0xFFFFAFCC))
          : (altTone ? const Color(0xFFF59E0B) : const Color(0xFFFDE68A));

      final double radius = 4.0 + 5.0 * _rand01(i, 0.21);
      final double speedPxPerSec = 60.0 + 40.0 * _rand01(i, 0.31);
      final double offsetPx = _rand01(i, 0.41) * size.width;
      final double lane = -20.0 * _rand01(i, 0.51) - 3.0;

      final double xBase = (bubbleTimeSec * speedPxPerSec + offsetPx) % (size.width + 100.0) - 50.0;

      if (xBase >= -radius && xBase <= size.width + radius) {
        final double bob = math.sin((xBase / size.width) * 2 * math.pi + i) * 2.0;
        final double y = baseY + size.height * 0.4 + lane + bob;

        bubblePaint.color = color.withOpacity(0.60);
        canvas.drawCircle(Offset(xBase, y), radius, bubblePaint);
        canvas.drawCircle(Offset(xBase - radius * 0.35, y - radius * 0.35), radius * 0.35, highlightPaint);
      }
    }

    canvas.restore();
  }

  // Helpers
  double _fract(double x) => x - x.floorToDouble();
  double _rand01(int i, double salt) {
    final double v = math.sin((i + 1) * 12.9898 + salt * 78.233) * 43758.5453123;
    return _fract(v.abs());
  }

  @override
  bool shouldRepaint(covariant _GlossyDividerPainter oldDelegate) =>
      oldDelegate.holeImage != holeImage ||
          oldDelegate.lettuceImage != lettuceImage ||
          oldDelegate.float != float ||
          oldDelegate.wave != wave ||
          oldDelegate.bubbleTime != bubbleTime;
}


class _TwoToneBorderPainter extends CustomPainter {
  const _TwoToneBorderPainter({
    required this.progressColor,
    required this.whiteColor,
    required this.borderWidth,
  });

  final Color progressColor;
  final Color whiteColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Define the circular rect
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Paint for the left portion border
    final leftPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Draw arc ONLY on the left half (from 90° to 270°)
    // Flutter uses radians: 0 rad = right, π/2 rad = bottom, π rad = left, 3π/2 rad = top
    canvas.drawArc(
      rect,
      math.pi / 2,   // start at 90° (top → left)
      math.pi,       // sweep 180° (top → left → bottom)
      false,
      leftPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TwoToneBorderPainter oldDelegate) =>
      oldDelegate.progressColor != progressColor ||
          oldDelegate.whiteColor != whiteColor ||
          oldDelegate.borderWidth != borderWidth;
}

class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.8),
                  widget.color.withOpacity(0.6 * _blinkAnimation.value),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                // Primary shadow for depth
                BoxShadow(
                  color: widget.color.withOpacity(0.4 * _blinkAnimation.value),
                  blurRadius: 12 + (8 * _blinkAnimation.value),
                  spreadRadius: 1 + (2 * _blinkAnimation.value),
                  offset: const Offset(0, 4),
                ),
                // Secondary shadow for more depth
                BoxShadow(
                  color: widget.color.withOpacity(0.2 * _blinkAnimation.value),
                  blurRadius: 20 + (10 * _blinkAnimation.value),
                  spreadRadius: 2 + (3 * _blinkAnimation.value),
                  offset: const Offset(0, 8),
                ),
                // White highlight for premium look
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(-2, -2),
                ),
                // Animated glow effect
                BoxShadow(
                  color: widget.color.withOpacity(0.6 * _blinkAnimation.value),
                  blurRadius: 25 * _blinkAnimation.value,
                  spreadRadius: 5 * _blinkAnimation.value,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Inner highlight overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: RadialGradient(
                          center: Alignment.topLeft,
                          radius: 1.2,
                          colors: [
                            Colors.white.withOpacity(0.4 * _blinkAnimation.value),
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Icon with shadow or loading indicator
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Icon(
                    widget.icon,
                    color: Colors.white,
                    size: 28,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


class _TdsDosingButton extends StatefulWidget {
  const _TdsDosingButton({
    required this.child,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  State<_TdsDosingButton> createState() => _TdsDosingButtonState();
}

class _TdsDosingButtonState extends State<_TdsDosingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _blinkAnimation,
        builder: (context, child) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  widget.color.withOpacity(0.8),
                  widget.color.withOpacity(0.6 * _blinkAnimation.value),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.8),
                width: 2,
              ),
              boxShadow: [
                // Primary shadow for depth
                BoxShadow(
                  color: widget.color.withOpacity(0.4 * _blinkAnimation.value),
                  blurRadius: 12 + (8 * _blinkAnimation.value),
                  spreadRadius: 1 + (2 * _blinkAnimation.value),
                  offset: const Offset(0, 4),
                ),
                // Secondary shadow for more depth
                BoxShadow(
                  color: widget.color.withOpacity(0.2 * _blinkAnimation.value),
                  blurRadius: 20 + (10 * _blinkAnimation.value),
                  spreadRadius: 2 + (3 * _blinkAnimation.value),
                  offset: const Offset(0, 8),
                ),
                // White highlight for premium look
                BoxShadow(
                  color: Colors.white.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(-2, -2),
                ),
                // Animated glow effect
                BoxShadow(
                  color: widget.color.withOpacity(0.6 * _blinkAnimation.value),
                  blurRadius: 25 * _blinkAnimation.value,
                  spreadRadius: 5 * _blinkAnimation.value,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Inner highlight overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: RadialGradient(
                          center: Alignment.topLeft,
                          radius: 1.2,
                          colors: [
                            Colors.white.withOpacity(0.4 * _blinkAnimation.value),
                            Colors.white.withOpacity(0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                // Icon with shadow or loading indicator
                Center(
                  child: widget.isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : widget.child,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlantGrowthProgressBar extends StatelessWidget {
  const _PlantGrowthProgressBar({
    required this.plantHealthMetric,
    required this.currentStage,
    required this.nextStage,
    required this.levelProgress,
    required this.currentStageLevel,
  });

  final PlantMetric plantHealthMetric;
  final PlantStage currentStage;
  final PlantStage nextStage;
  final double levelProgress;
  final int currentStageLevel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.5,
        child: Column(
          children: [
            // Combined progress bars container with separate text overlay
            SizedBox(
              height: 80, // Much larger height for the expanded progress bars
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none, // Allow circles to extend outside
                children: [
                  // Background: Progress bars container
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main health progress bar - clean
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7 - 60, // Much longer width
                        height: 24, // Much bigger height for prominence
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12), // Adjusted for new height
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: LinearProgressIndicator(
                            value: plantHealthMetric.progress,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              plantHealthMetric.endColor.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3), // Balanced gap between bars
                      // Level progress bar (yellow) - clean
                      Container(
                        width: MediaQuery.of(context).size.width * 0.7 - 60, // Same longer width as main bar
                        height: 16, // Expanded height to match proportions
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8), // Adjusted for new height
                          color: Colors.white.withOpacity(0.15),
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: levelProgress,
                            backgroundColor: Colors.transparent,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFF59E0B), // Yellow color for level progress
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Foreground: Percentage text container
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Main health percentage text - perfectly centered
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7 - 60,
                        height: 24,
                        child: Center(
                          child: Text(
                            plantHealthMetric.value,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3), // Match gap between bars
                      // Level percentage text - perfectly centered
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7 - 60,
                        height: 16,
                        child: Center(
                          child: Text(
                            '${(levelProgress * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Start circle with current stage icon - gamified border color
                  Positioned(
                    left: -18 - 22, // More gaps: -18 (circle position) - 22 (gap)
                    child: Container(
                      width: 60, // Even bigger circles
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentStage.stageColor,
                        border: Border.all(
                          color: const Color(0xFFF59E0B), // Yellow color matching level progress bar
                          width: 5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withOpacity(0.7), // Yellow shadow matching level progress
                            blurRadius: 20, // Much stronger shadow
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/lvl_$currentStageLevel.png',
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  // End circle with next stage icon - gamified two-tone border
                  Positioned(
                    right: -18 - 22, // More gaps: -18 (circle position) - 22 (gap)
                    child: SizedBox(
                      width: 60, // Even bigger circles
                      height: 60,
                      child: Stack(
                        children: [
                          // Base circle
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: nextStage.stageColor,
                              boxShadow: [
                                BoxShadow(
                                  color: nextStage.stageColor.withOpacity(0.7),
                                  blurRadius: 20,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/lvl_${currentStageLevel < 4 ? currentStageLevel + 1 : 4}.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.contain,
                            ),
                          ),
                          // Two-tone border overlay (only when levelProgress >= 0.95)
                          if (levelProgress >= 0.95)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: _TwoToneBorderPainter(
                                    progressColor: const Color(0xFFF59E0B), // Yellow matching level bar
                                    whiteColor: Colors.white,
                                    borderWidth: 5,
                                  ),
                                ),
                              ),
                            )
                          else
                          // White border when progress < 95%
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white, // White border for < 95%
                                      width: 5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}