# OpenCode Go — Reasoning Effort Support per Model

Tested 2026-05-07 against `https://opencode.ai/zen/go/v1/chat/completions`.

## Results

| Model | max | xhigh | high | medium | low | minimal | minimum | none |
|-------|:---:|:-----:|:----:|:------:|:---:|:-------:|:-------:|:----:|
| minimax-m2.7 | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| minimax-m2.5 | ✗ | ✗ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| kimi-k2.6 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| kimi-k2.5 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| glm-5.1 | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ |
| glm-5 | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✓ |
| deepseek-v4-pro | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| deepseek-v4-flash | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✗ | ✗ |
| qwen3.6-plus | ✗ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ | ✓ |
| qwen3.5-plus | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| mimo-v2-pro | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| mimo-v2-omni | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| mimo-v2.5-pro | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |
| mimo-v2.5 | ✗ | ✓ | ✓ | ✓ | ✓ | ✓ | ✗ | ✓ |

## Universally Supported

**`low`, `medium`, `high`, `xhigh`** — accepted by all 14 models.

## By Provider Backend

| Backend | Models | Supports |
|---------|--------|----------|
| MiniMax | minimax-m2.5 | low, medium, high *only* (must enable reasoning) |
| Kimi | kimi-k2.5, kimi-k2.6 | xhigh, high, medium, low, minimal, none |
| GLM | glm-5, glm-5.1 | xhigh, high, medium, low, none |
| DeepSeek | deepseek-v4-* | max, xhigh, high, medium, low |
| Alibaba (Qwen) | qwen3.*-plus | xhigh, high, medium, low, minimum, none |
| MiMo | mimo-v2-*, mimo-v2.5-* | xhigh, high, medium, low, minimal, none |

## Test Commands

```bash
KEY="sk-YOUR_KEY"
BASE="https://opencode.ai/zen/go/v1/chat/completions"

# Test a single model/effort combo
curl -s -w "\nHTTP %{http_code}" $BASE \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"MODEL_ID","messages":[{"role":"user","content":"hi"}],"max_tokens":1,"stream":false,"reasoning_effort":"EFFORT"}'

# Batch test all models against all efforts
for model in minimax-m2.7 minimax-m2.5 kimi-k2.6 kimi-k2.5 glm-5.1 glm-5 \
            deepseek-v4-pro deepseek-v4-flash qwen3.6-plus qwen3.5-plus \
            mimo-v2-pro mimo-v2-omni mimo-v2.5-pro mimo-v2.5; do
  echo "=== $model ==="
  for effort in max xhigh high medium low minimal minimum none; do
    code=$(curl -s -o /dev/null -w "%{http_code}" $BASE \
      -H "Authorization: Bearer $KEY" \
      -H "Content-Type: application/json" \
      -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"stream\":false,\"reasoning_effort\":\"$effort\"}")
    [ "$code" = "200" ] && echo "  ✓ $effort" || echo "  ✗ $effort"
  done
done
```
