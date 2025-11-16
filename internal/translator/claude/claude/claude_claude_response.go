package claude

import (
	"context"
	"strings"

	"github.com/tidwall/gjson"
)

// FilterClaudeResponseStream removes duplicated content_block_stop events emitted by Claude.
// Claude occasionally sends a stop event that only carries a signature delta immediately before
// the actual stop notification. This translator buffers SSE event blocks so we can drop the
// redundant signature-only events while emitting the canonical stop event.
func FilterClaudeResponseStream(_ context.Context, _ string, _, _, rawJSON []byte, param *any) []string {
	if *param == nil {
		*param = &claudeSelfStreamState{}
	}
	state := (*param).(*claudeSelfStreamState)
	return state.consume(rawJSON)
}

// PassthroughClaudeResponse returns non-streaming responses unchanged.
func PassthroughClaudeResponse(_ context.Context, _ string, _, _, rawJSON []byte, _ *any) string {
	return string(rawJSON)
}

type claudeSelfStreamState struct {
	pendingLines     []string
	pendingEventName string
	pendingData      strings.Builder
	hasPendingEvent  bool

	lastEmittedEvent    string
	lastEmittedIndex    int64
	lastEmittedHasIndex bool
}

func (s *claudeSelfStreamState) consume(raw []byte) []string {
	line := strings.TrimRight(string(raw), "\r")
	trimmed := strings.TrimSpace(line)

	// Forward keep-alive comment lines as-is.
	if strings.HasPrefix(line, ":") {
		return []string{line + "\n"}
	}

	var out []string
	switch {
	case trimmed == "":
		out = append(out, s.flush()...)
	case strings.HasPrefix(line, "event:"):
		out = append(out, s.flush()...)
		s.pendingLines = []string{line}
		s.pendingEventName = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
		s.hasPendingEvent = true
	case strings.HasPrefix(line, "data:"):
		if !s.hasPendingEvent && len(s.pendingLines) == 0 {
			s.hasPendingEvent = true
		}
		s.pendingLines = append(s.pendingLines, line)
		payload := strings.TrimLeft(line[len("data:"):], " ")
		if s.pendingData.Len() > 0 {
			s.pendingData.WriteByte('\n')
		}
		s.pendingData.WriteString(payload)
	default:
		// Include any other SSE fields (e.g., id:, retry:) inside the event block.
		s.pendingLines = append(s.pendingLines, line)
	}

	return out
}

func (s *claudeSelfStreamState) flush() []string {
	if len(s.pendingLines) == 0 {
		return nil
	}

	var out []string
	eventPayload := s.pendingData.String()
	eventType := s.pendingEventName
	var eventIndex int64
	eventHasIndex := false
	if eventPayload != "" {
		payloadResult := gjson.Parse(eventPayload)
		if eventType == "" {
			eventType = payloadResult.Get("type").String()
		}
		if idx := payloadResult.Get("index"); idx.Exists() {
			eventIndex = idx.Int()
			eventHasIndex = true
		}

		if eventType == "content_block_stop" {
			deltaType := payloadResult.Get("delta.type").String()
			if deltaType == "signature_delta" {
				s.resetPending()
				return nil
			}
			if s.lastEmittedEvent == "content_block_stop" {
				if eventHasIndex && s.lastEmittedHasIndex && s.lastEmittedIndex == eventIndex {
					s.resetPending()
					return nil
				}
				if !eventHasIndex && !s.lastEmittedHasIndex {
					s.resetPending()
					return nil
				}
			}
		}
	}

	block := strings.Join(s.pendingLines, "\n") + "\n\n"
	out = append(out, block)

	// Update last emitted event markers.
	s.lastEmittedEvent = eventType
	s.lastEmittedHasIndex = eventHasIndex
	if eventHasIndex {
		s.lastEmittedIndex = eventIndex
	}

	s.resetPending()
	return out
}

func (s *claudeSelfStreamState) resetPending() {
	s.pendingLines = nil
	s.pendingEventName = ""
	s.pendingData.Reset()
	s.hasPendingEvent = false
}

