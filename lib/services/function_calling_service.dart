import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_service.dart';
import 'browser_automation_service.dart';

/// Service for handling AI function calling in browser automation
/// Processes AI responses that contain function calls and executes them
class FunctionCallingService {
  final AIService _aiService;
  final BrowserAutomationService _browserAutomationService;

  FunctionCallingService(this._aiService, this._browserAutomationService);

  /// Process an AI response that may contain function calls
  Future<String> processAIResponse(String aiResponse) async {
    try {
      // Parse the AI response to check for function calls
      final responseData = jsonDecode(aiResponse);

      // Check if this is a function call response
      if (responseData is Map<String, dynamic> &&
          responseData.containsKey('function_call')) {
        final functionCall = responseData['function_call'];
        final functionName = functionCall['name'];
        final parameters = functionCall['arguments'] ?? functionCall['parameters'] ?? {};

        debugPrint('Executing function call: $functionName with parameters: $parameters');

        // Execute the function
        final result = await _browserAutomationService.executeFunction(functionName, parameters);

        // Return the result in a format the AI can understand
        return jsonEncode({
          'function_result': {
            'name': functionName,
            'result': result,
          }
        });
      }

      // If no function call, return the response as-is
      return aiResponse;
    } catch (e) {
      debugPrint('Error processing AI response: $e');
      return aiResponse; // Return original response on error
    }
  }

  /// Generate an AI response with function calling capabilities
  Future<String> generateResponseWithFunctions(
    String userMessage,
    List<Map<String, String>> chatHistory,
  ) async {
    // First, get the AI response with function definitions
    final functionPrompt = '''
You are an AI browser assistant that can control the browser through function calls.

Available functions:
${_browserAutomationService.functionDefinitions.keys.map((name) {
      final def = _browserAutomationService.functionDefinitions[name];
      return '- $name: ${def['description']}';
    }).join('\n')}

When you need to perform browser actions, respond with a JSON object containing a "function_call" field:
{
  "function_call": {
    "name": "function_name",
    "arguments": {
      "param1": "value1",
      "param2": "value2"
    }
  }
}

For multi-step tasks, you can make multiple function calls in sequence. After each function call, you'll receive the result and can continue with the next step.

User request: $userMessage

${chatHistory.isNotEmpty ? 'Previous conversation:\n${chatHistory.map((msg) => '${msg['role']}: ${msg['content']}').join('\n')}' : ''}

Respond with either a normal message or a function call as needed.
''';

    final aiResponse = await _aiService.generateChatResponse(
      functionPrompt,
      chatHistory,
    );

    // Process any function calls in the response
    return await processAIResponse(aiResponse);
  }

  /// Generate a streaming response with multi-step function calling capabilities
  Stream<String> generateStreamingResponseWithFunctions(
    String userMessage,
    List<Map<String, String>> chatHistory,
  ) async* {
    // Quick decision: does this request need browser automation functions?
    final planningPrompt = '''
You are a browser automation assistant. Available functions: ${_browserAutomationService.functionDefinitions.keys.join(', ')}

User request: "$userMessage"

Do you need to use any browser automation functions to fulfill this request?

IMPORTANT: If you need to use browser functions, respond ONLY with a JSON function call like this:
{"function_call": {"name": "function_name", "arguments": {"param": "value"}}}

If no browser automation is needed (just conversation/chat), respond with: {"action": "complete"}

Do not include any other text or explanations.
''';

    final planningResponse = await _aiService.generateChatResponse(planningPrompt, chatHistory);
    debugPrint('FunctionCallingService: Planning response: $planningResponse');

    // Check if planning response contains a function call
    if (containsFunctionCall(planningResponse)) {
      debugPrint('FunctionCallingService: Contains function call');
      final functionCall = extractFunctionCall(planningResponse);
      if (functionCall != null) {
        // Show that we're planning
        yield 'Planning: Analyzing request and determining next steps...\n\n';

        // Execute the first function
        final result = await _browserAutomationService.executeFunction(
          functionCall['name'],
          functionCall['arguments'] ?? functionCall['parameters'] ?? {},
        );

        // Show execution result
        yield 'Executing: ${functionCall['name']}\n';
        yield 'Result: ${result.toString()}\n\n';

        // Continue with multi-step execution loop
        debugPrint('FunctionCallingService: Starting multi-step workflow');
        await for (final step in _executeMultiStepWorkflow(userMessage, chatHistory, result)) {
          yield step;
        }
        debugPrint('FunctionCallingService: Multi-step workflow completed');
      } else {
        // No valid function call found, fall back to direct streaming
        await for (final chunk in _aiService.generateChatResponseStream(userMessage, chatHistory)) {
          yield chunk;
        }
      }
    } else {
      // No function call needed, use direct streaming AI response
      debugPrint('FunctionCallingService: No function call detected, using direct streaming for message: $userMessage');
      await for (final chunk in _aiService.generateChatResponseStream(userMessage, chatHistory)) {
        yield chunk;
      }
      debugPrint('FunctionCallingService: Direct streaming completed');
    }
  }

  /// Execute multi-step workflow until goal is reached
  Stream<String> _executeMultiStepWorkflow(
    String originalUserRequest,
    List<Map<String, String>> chatHistory,
    Map<String, dynamic> lastResult,
  ) async* {
    int stepCount = 1;
    const maxSteps = 50; // Prevent infinite loops

    while (stepCount < maxSteps) {
      // Check if goal is achieved or if more steps are needed
      final continuePrompt = '''
Previous result: ${lastResult.toString()}

Based on this result, do you need to take another browser action for: "$originalUserRequest"?

Available functions: ${_browserAutomationService.functionDefinitions.keys.join(', ')}

If you need another browser action, respond with JSON: {"function_call": {"name": "function_name", "arguments": {"param": "value"}}}

If goal is complete, respond with: {"action": "complete"}

If you need to give a final answer, respond with: {"response": "Your answer here"}
''';

      final continueResponse = await _aiService.generateChatResponse(continuePrompt, chatHistory);

      // Parse the JSON response
      try {
        final responseData = jsonDecode(continueResponse.trim());

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('function_call')) {
            // Execute another function
            final functionCall = responseData['function_call'];
            final result = await _browserAutomationService.executeFunction(
              functionCall['name'],
              functionCall['arguments'] ?? functionCall['parameters'] ?? {},
            );

            yield 'Executing: ${functionCall['name']}\n';
            yield 'Result: ${result.toString()}\n\n';

            // Update last result for next iteration
            lastResult = result;
            stepCount++;

            // Add a small delay between steps
            await Future.delayed(const Duration(seconds: 1));
          } else if (responseData['action'] == 'complete') {
            // Goal achieved
            yield 'Goal achieved! All steps completed.\n';
            break;
          } else if (responseData.containsKey('response')) {
            // Final response to user
            yield 'Final response: ${responseData['response']}\n';
            break;
          } else {
            // Unknown response format, continue to next step
            yield 'Unknown response format, continuing...\n';
            stepCount++;
            await Future.delayed(const Duration(seconds: 1));
          }
        } else {
          // Invalid response format, continue to next step
          yield 'Invalid response format, continuing...\n';
          stepCount++;
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        // Error parsing response, continue to next step
        yield 'Error parsing response, continuing to next step...\n';
        stepCount++;
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (stepCount >= maxSteps) {
      debugPrint('FunctionCallingService: Reached maximum steps ($maxSteps), ending workflow');
      yield '\n\nReached maximum steps ($maxSteps). Stopping workflow.';
    } else {
      debugPrint('FunctionCallingService: Workflow completed normally');
    }
  }

  /// Check if a response contains function calls
  bool containsFunctionCall(String response) {
    // Look for JSON objects containing function_call within the text
    final jsonPattern = RegExp(r'\{[^}]*"function_call"[^}]*\}');
    return jsonPattern.hasMatch(response);
  }

  /// Extract function call details from a response
  Map<String, dynamic>? extractFunctionCall(String response) {
    try {
      // First try to parse the entire response as JSON
      final data = jsonDecode(response);
      if (data is Map<String, dynamic> && data.containsKey('function_call')) {
        return data['function_call'] as Map<String, dynamic>;
      }
    } catch (e) {
      // If that fails, look for JSON objects within the text
      final jsonPattern = RegExp(r'\{[^{}]*"function_call"[^{}]*\}');
      final match = jsonPattern.firstMatch(response);
      if (match != null) {
        try {
          final jsonStr = match.group(0)!;
          final data = jsonDecode(jsonStr);
          if (data is Map<String, dynamic> && data.containsKey('function_call')) {
            return data['function_call'] as Map<String, dynamic>;
          }
        } catch (e2) {
          debugPrint('Error parsing extracted JSON: $e2');
        }
      }
    }
    return null;
  }
}
