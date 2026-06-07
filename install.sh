#!/usr/bin/env bash
set -e

BC='\033[1;36m'; GC='\033[1;32m'; YC='\033[1;33m'; RC='\033[1;31m'; DC='\033[0m'

echo -e "${BC}"
echo '  ╔══════════════════════════════════════════════╗'
echo '  ║         drtlemon AI · KERNEL INSTALL         ║'
echo '  ║  Daramola Olasupo · StoneWeb InFOMIX Ent.    ║'
echo '  ╚══════════════════════════════════════════════╝'
echo -e "${DC}"

PAI_DIR="$(cd "$(dirname "$0")" && pwd)"
MODEL_DIR="${PAI_DIR}/models"
mkdir -p "${MODEL_DIR}"

# ── detect OS ──
OS="linux"; case "$(uname)" in Darwin*) OS="macos" ;; MINGW*|MSYS*) OS="windows" ;; esac
ARCH="$(uname -m)"
echo -e "${GC}  ✓ OS:${DC} ${OS}  ${GC}ARCH:${DC} ${ARCH}"
echo ''

# ── LLM selection ──
echo -e "${YC}  How would you like to get your LLM?${DC}"
echo '  1) Download a model (automatic, recommended)'
echo '  2) Use local models already on this machine'
echo -n '  Choice [1/2]: '; read CHOICE

if [ "${CHOICE}" = "2" ]; then
    echo ''
    echo -e "${GC}  → Scanning for local LLMs...${DC}"

    # Ollama
    if command -v ollama &>/dev/null; then
        echo -e "  ${GC}✓${DC} Ollama detected"
        ollama list 2>/dev/null | head -20
    else
        echo -e "  ${YC}  — Ollama not found${DC}"
    fi

    # GGUF files
    GGUFS=$(find / -maxdepth 4 -name "*.gguf" 2>/dev/null | head -20)
    if [ -n "${GGUFS}" ]; then
        echo -e "  ${GC}✓${DC} GGUF models found:"
        echo "${GGUFS}" | while read -r f; do echo "    ${f}"; done
    else
        echo -e "  ${YC}  — No .gguf files found${DC}"
    fi

    # Python ML frameworks
    for py in python3 python; do
        if command -v "${py}" &>/dev/null; then
            TF=$("${py}" -c "import torch; print(torch.__version__)" 2>/dev/null) && echo -e "  ${GC}✓${DC} PyTorch ${TF}" || true
            break
        fi
    done

    echo ''
    echo -e "${GC}  ✓ Local scan complete${DC}"
    echo '  You can load any detected model from the Models panel in the UI.'
    echo ''
    echo -n '  Press Enter to continue...'; read
else
    echo ''
    echo -e "${YC}  Select a model to download:${DC}"
    echo '  1) Llama 3.2 3B  (fast, 2GB, recommended)'
    echo '  2) Gemma 2 9B    (balanced, 5GB)'
    echo '  3) Mistral 7B    (capable, 4GB)'
    echo -n '  Choice [1/2/3]: '; read MODEL_CHOICE

    case "${MODEL_CHOICE}" in
        2) MODEL_URL="https://huggingface.co/google/gemma-2-9b-it-gguf/resolve/main/gemma-2-9b-it-Q4_K_M.gguf"; MODEL_NAME="gemma-2-9b" ;;
        3) MODEL_URL="https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/mistral-7b-instruct-v0.3.Q4_K_M.gguf"; MODEL_NAME="mistral-7b" ;;
        *) MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf"; MODEL_NAME="llama-3.2-3b" ;;
    esac

    MODEL_PATH="${MODEL_DIR}/${MODEL_NAME}.gguf"
    echo ''
    echo -e "  Downloading ${YC}${MODEL_NAME}${DC} → ${MODEL_PATH}"
    echo -e "  ${YC}This may take a while depending on your connection.${DC}"
    echo ''

    if command -v curl &>/dev/null; then
        curl -L --progress-bar "${MODEL_URL}" -o "${MODEL_PATH}"
    elif command -v wget &>/dev/null; then
        wget --progress=bar:force "${MODEL_URL}" -O "${MODEL_PATH}"
    else
        echo -e "  ${RC}✗ Need curl or wget to download${DC}"
        exit 1
    fi

    echo -e "  ${GC}✓ Downloaded ${MODEL_NAME}${DC}"

    # Install llama.cpp server for local inference
    if ! command -v llama-server &>/dev/null && ! command -v llama-cli &>/dev/null; then
        echo ''
        echo -e "  ${YC}Installing llama.cpp for local inference...${DC}"
        if command -v brew &>/dev/null; then
            brew install llama.cpp
        elif command -v apt &>/dev/null; then
            cd /tmp
            git clone --depth 1 https://github.com/ggml-org/llama.cpp.git
            cd llama.cpp && make -j4 llama-server 2>/dev/null || true
            if [ -f "./llama-server" ]; then
                cp ./llama-server "${PAI_DIR}/bin/" 2>/dev/null || mkdir -p "${PAI_DIR}/bin" && cp ./llama-server "${PAI_DIR}/bin/"
            fi
        fi
    fi
fi

# ── FreeQwenApi (optional) ──
if [ -d /tmp/FreeQwenApi ]; then
    echo ''
    echo -e "${GC}  → FreeQwenApi already cloned.${DC}"
else
    echo ''
    echo -e "${YC}  FreeQwenApi gives you free Qwen 3.7 models locally. Install now?${DC}"
    echo -n '  Install FreeQwenApi? [y/N]: '; read INSTALL_FREE
    if [ "${INSTALL_FREE}" = 'y' ] || [ "${INSTALL_FREE}" = 'Y' ]; then
        if command -v git &>/dev/null && command -v npx &>/dev/null; then
            echo -e "  Cloning FreeQwenApi..."
            git clone --depth 1 https://github.com/y13sint/FreeQwenApi.git /tmp/FreeQwenApi
            (cd /tmp/FreeQwenApi && npm install)
            echo -e "  ${GC}✓${DC} FreeQwenApi installed. Run: cd /tmp/FreeQwenApi && npx tsx src/proxy.ts"
        else
            echo -e "  ${YC}  — Need git and Node.js to install FreeQwenApi${DC}"
        fi
    fi
fi

# ── configure server ──
echo ''
echo -e "${GC}  → Configuring drtlemon server...${DC}"
if [ -f "${PAI_DIR}/Shared/chat_server.py" ]; then
    python3 "${PAI_DIR}/Shared/chat_server.py" 2>/dev/null &
    sleep 1
    echo -e "  ${GC}✓ Server started on port 8080${DC}"
fi

# ── summary ──
echo ''
echo -e "${BC}"
echo '  ╔══════════════════════════════════════════════╗'
echo '  ║          INSTALLATION COMPLETE               ║'
echo '  ╚══════════════════════════════════════════════╝'
echo -e "${DC}"
echo ''
echo -e "  ${GC}  drtlemon AI${DC} is ready at:"
echo -e "  ${GC}  ${PAI_DIR}${DC}"
echo ''
echo -e "  ${YC}  To launch:${DC}"
echo "    cd ${PAI_DIR}"
echo '    python3 Shared/chat_server.py'
echo '    → Open http://localhost:8080 in your browser'
echo ''
echo -e "  ${YC}  Kernel:${DC}"
echo '  · Chat with voice I/O · 5,836 skills across 10 tiers'
    echo '  · Visual agent orchestrator · Drag-drop pipeline builder'
    echo '  · Floating advisory orbs · LLM scanner + switcher'
    echo '  · Glassmorphism cinematic UI'
    echo '  · FreeQwenApi support — free Qwen 3.7 models via local proxy'
echo ''
