# Crea il container distrobox per MATLAB R2026b con supporto GPU NVIDIA.
# Il container usa PRIME offload per il rendering OpenGL (dGPU RTX 5060) e ha già
# libcuda + /dev/nvidia* per il compute CUDA (gpuArray, Parallel Toolbox).
# MATLAB viene lanciato dall'host tramite ~/.local/bin/matlab (stowato da 40-stow.sh).

mod_distrobox() {
  log "Distrobox: container MATLAB R2026b…"

  have distrobox || { warn "distrobox non trovato — salto mod_distrobox"; return 0; }

  local ini="$HOME/.config/distrobox/matlab.ini"
  [[ -f "$ini" ]] || { warn "manifest assente: $ini (esegui prima mod_stow)"; return 1; }

  # Idempotente: non ricreare se il container esiste già.
  if distrobox list 2>/dev/null | grep -q 'matlab-r2026b'; then
    ok "container matlab-r2026b già presente — salto la creazione"
    return 0
  fi

  log "Creazione container matlab-r2026b (ubuntu:24.04, --nvidia)…"
  run distrobox assemble create --file "$ini"
  ok "container matlab-r2026b creato"
}
