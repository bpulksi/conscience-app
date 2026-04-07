import 'package:flutter/material.dart';

/// Displays the result of a Cloud Function call — success data or error message.
///
/// Usage:
///   FunctionResultCard(result: _result)
///
/// Where [_result] is a [FunctionResult] produced by calling a service method
/// and catching any [FirebaseFunctionsException].
class FunctionResultCard extends StatelessWidget {
  final FunctionResult? result;

  const FunctionResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    if (r == null) return const SizedBox.shrink();

    final isSuccess = r.error == null;
    final color = isSuccess ? Colors.green.shade50 : Colors.red.shade50;
    final borderColor = isSuccess ? Colors.green.shade300 : Colors.red.shade300;
    final icon = isSuccess ? Icons.check_circle_outline : Icons.error_outline;
    final iconColor = isSuccess ? Colors.green.shade700 : Colors.red.shade700;

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isSuccess ? r.output! : r.error!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSuccess
                          ? Colors.green.shade900
                          : Colors.red.shade900,
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

class FunctionResult {
  /// Short label describing which function was called.
  final String label;

  /// Human-readable output on success.
  final String? output;

  /// Error message on failure.
  final String? error;

  const FunctionResult.success({required this.label, required String this.output})
      : error = null;

  const FunctionResult.failure({required this.label, required String this.error})
      : output = null;
}
