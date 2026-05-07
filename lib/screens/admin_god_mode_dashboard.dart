import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/offline_queue_service.dart';
import '../services/system_broadcast_service.dart';
import '../core/tokens.dart';

class AdminGodModeDashboard extends StatefulWidget {
  const AdminGodModeDashboard({super.key});

  @override
  State<AdminGodModeDashboard> createState() => _AdminGodModeDashboardState();
}

class _AdminGodModeDashboardState extends State<AdminGodModeDashboard> {
  final TextEditingController _megaphoneController = TextEditingController();
  final TextEditingController _sandboxController = TextEditingController();
  
  bool _isFlushing = false;
  String _activeImpersonation = "";

  @override
  void initState() {
    super.initState();
    _checkSandboxState();
  }

  Future<void> _checkSandboxState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _activeImpersonation = prefs.getString('impersonated_student_batch') ?? "";
    });
  }

  void _triggerFlush() async {
    setState(() => _isFlushing = true);
    bool success = await OfflineQueueService().flushQueue();
    // Simulate slight delay for heavy UI feel
    await Future.delayed(const Duration(milliseconds: 600)); 
    setState(() => _isFlushing = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Offline Cloud Sync Successful!" : "Sync Failed. Elements preserved."),
          backgroundColor: success ? IrisTokens.success : IrisTokens.error,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  Future<void> _engageSandbox() async {
    if (_sandboxController.text.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    
    // Enter Sandbox (overrides the global 'student_batch' reader)
    await prefs.setString('impersonated_student_batch', _sandboxController.text.toUpperCase());
    
    // Fire haptics (pseudo)
    SystemBroadcastService().triggerLocalOverride(
      "Sandbox Mode Engaged", 
      "You are now viewing the app exactly as Batch: ${_sandboxController.text.toUpperCase()}",
      isUrgent: true
    );
    
    _checkSandboxState();
  }

  Future<void> _exitSandbox() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('impersonated_student_batch');
    
    SystemBroadcastService().triggerLocalOverride(
      "Sandbox Terminated", 
      "Admin context restored.",
    );
    _checkSandboxState();
  }

  Future<void> _broadcastMegaphone() async {
    final text = _megaphoneController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isFlushing = true); // Reuse the UI spinner
    
    // Call our Cloudflare wrapper logic
    bool success = await SystemBroadcastService().publishGlobalNetworkOverride(
      "Admin Network Override", 
      text, 
      isUrgent: true
    );
    
    setState(() { 
       _isFlushing = false;
       if (success) _megaphoneController.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? "Global Broadcast Fired!" : "Transmission failed. Is the Cloudflare Worker active?"),
          backgroundColor: success ? IrisTokens.brand : IrisTokens.error,
        )
      );
      
      // Fallback: Manually trigger the local pill overlay if the server push fails so the admin at least sees the UI logic
      SystemBroadcastService().triggerLocalOverride(
        "Admin Network Override", 
        text,
        isUrgent: true
      );
    }
  }

  @override
  void dispose() {
    _megaphoneController.dispose();
    _sandboxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D0E15) : const Color(0xFFF1F5F9);
    final cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('OmniFlow Center', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isFlushing ? Icons.cloud_sync_rounded : Icons.cloud_done_rounded, 
                       color: _isFlushing ? IrisTokens.brand : IrisTokens.success),
            onPressed: _isFlushing ? null : _triggerFlush,
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ==========================================
            // BENTO: SANDBOX IMPERSONATOR
            // ==========================================
            _buildBentoCard(
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.theater_comedy_rounded, color: IrisTokens.brandLight, size: 28),
                      const SizedBox(width: 12),
                      const Text("Student Sandbox", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeImpersonation.isNotEmpty 
                        ? "Currently impersonating: $_activeImpersonation\nUI functions will simulate this batch."
                        : "Inject a Batch ID to view the application exactly like that student sees it, without modifying database roles.",
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  
                  if (_activeImpersonation.isEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _sandboxController,
                            decoration: InputDecoration(
                              hintText: "Enter Batch (e.g. FA21-BSE)",
                              filled: true,
                              fillColor: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0)
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _engageSandbox,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: IrisTokens.brand,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          child: const Text("Engage", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _exitSandbox,
                        icon: const Icon(Icons.exit_to_app_rounded, color: IrisTokens.error),
                        label: const Text("Terminate Sandbox Override", style: TextStyle(color: IrisTokens.error)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: IrisTokens.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                        ),
                      ),
                    )
                ],
              ),
            ),
            
            const SizedBox(height: 16),

            // ==========================================
            // BENTO GRID ROW
            // ==========================================
            Row(
              children: [
                Expanded(
                  child: _buildBentoCard(
                    height: 180,
                    cardColor: cardColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.dvr_rounded, color: IrisTokens.success, size: 48),
                        const SizedBox(height: 12),
                        const Text("System Core", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text("All Systems Operational", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    )
                  )
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildBentoCard(
                    height: 180,
                    cardColor: cardColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_rounded, color: IrisTokens.warning, size: 48),
                        const SizedBox(height: 12),
                        const Text("Offline Sync", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Text("Ready to Flush", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        SizedBox(
                           height: 30,
                           child: ElevatedButton(
                             onPressed: _triggerFlush,
                             style: ElevatedButton.styleFrom(backgroundColor: IrisTokens.warning),
                             child: const Text("Sync Now", style: TextStyle(fontSize: 12, color: Colors.white)),
                           )
                        )
                      ],
                    )
                  )
                ),
              ],
            ),
            
            const SizedBox(height: 16),

            // ==========================================
            // BENTO: BROADCAST MEGAPHONE
            // ==========================================
             _buildBentoCard(
              cardColor: cardColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: IrisTokens.error, size: 28),
                      const SizedBox(width: 12),
                      const Text("System Override Broadcast", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Send an immediate push notification dropdown to all active users bypassing limits using the Cloudflare worker.",
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _megaphoneController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Enter urgent announcement...",
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(16)
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _broadcastMegaphone,
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text("Broadcast to Network", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IrisTokens.error,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoCard({required Widget child, required Color cardColor, double? height}) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 4)
          )
        ],
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5)
      ),
      child: child,
    );
  }
}
