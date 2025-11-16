package claude

import "bytes"

// ConvertClaudeRequestToClaude is a passthrough converter for Claude requests.
// We still clone the payload to avoid mutating caller buffers.
func ConvertClaudeRequestToClaude(_ string, inputRawJSON []byte, _ bool) []byte {
	return bytes.Clone(inputRawJSON)
}

