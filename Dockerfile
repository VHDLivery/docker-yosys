# Erweitert das GHDL-Image um Yosys (aus den Quellen, versioniert)
# sowie das ghdl-yosys-plugin für VHDL-Synthese mit "yosys -m ghdl".
#
# WICHTIG – Versionskopplung:
#   Das Basis-Image enthält GHDL v6.0.0. Das ghdl-yosys-plugin folgt der
#   GHDL-Entwicklung (master braucht ein neueres libghdl-API) und dem
#   Yosys-API (Yosys >= 0.70 hat ein neues IdString-API).
#   Getestete, zueinander passende Kombination:
#     GHDL v6.0.0  +  ghdl-yosys-plugin Tag "ghdl-v6.0.0"  +  Yosys v0.69
#   Wird GHDL im Basis-Image aktualisiert, können YOSYS_VERSION und
#   GHDL_YOSYS_PLUGIN_REF entsprechend angehoben werden.
#

FROM ghcr.io/vhdlivery/docker-ghdl:v1.0.0

ARG YOSYS_VERSION=v0.69
ARG GHDL_YOSYS_PLUGIN_REF=ghdl-v6.0.0

# Das Basis-Image endet als Benutzer fpga-env (UID/GID 1000) -> für die Installation auf root (UID 0)
USER 0
ARG DEBIAN_FRONTEND=noninteractive

# Build- und Laufzeitabhängigkeiten von Yosys (CMake-Build, kein Boost nötig)
# DL3008 bewusst ignoriert: Exakte Paketversionen verschwinden aus dem Ubuntu-Archiv,
# sobald Sicherheitsupdates erscheinen, und würden den Build dann brechen. Reproduzierbarkeit
# kommt hier über das gepinnte Basis-Image sowie die gepinnten Yosys-/Plugin-Tags.
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        clang \
        lld \
        bison \
        flex \
        libfl-dev \
        gawk \
        git \
        pkg-config \
        python3 \
        libreadline-dev \
        tcl-dev \
        libffi-dev \
        zlib1g-dev \
        graphviz \
        xdot \
    && rm -rf /var/lib/apt/lists/*

# Yosys bauen und nach /usr/local installieren
RUN git clone --depth 1 --branch "${YOSYS_VERSION}" --recurse-submodules --shallow-submodules \
        https://github.com/YosysHQ/yosys.git /tmp/yosys \
    && cmake -S /tmp/yosys -B /tmp/yosys/build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=/usr/local \
        -DCMAKE_C_COMPILER=clang \
        -DCMAKE_CXX_COMPILER=clang++ \
        -DYOSYS_ENABLE_UNIT_TESTS=OFF \
    && cmake --build /tmp/yosys/build --parallel "$(nproc)" \
    && cmake --install /tmp/yosys/build \
    && rm -rf /tmp/yosys

# ghdl-yosys-plugin bauen (nutzt libghdl aus der GHDL-Installation des Basis-Images)
RUN git clone --depth 1 --branch "${GHDL_YOSYS_PLUGIN_REF}" \
        https://github.com/ghdl/ghdl-yosys-plugin.git /tmp/ghdl-yosys-plugin \
    && make -C /tmp/ghdl-yosys-plugin GHDL=ghdl YOSYS_CONFIG=yosys-config \
    && make -C /tmp/ghdl-yosys-plugin install GHDL=ghdl YOSYS_CONFIG=yosys-config \
    && rm -rf /tmp/ghdl-yosys-plugin

# Funktionstest während des Builds: kleines VHDL-Design mit GHDL-Plugin synthetisieren
WORKDIR /tmp/yosys-test
RUN printf '%s\n' \
        'library ieee; use ieee.std_logic_1164.all; use ieee.numeric_std.all;' \
        'entity counter is port (clk, rst, en : in std_logic; q : out std_logic_vector(3 downto 0)); end entity;' \
        'architecture rtl of counter is signal cnt : unsigned(3 downto 0) := (others => '"'"'0'"'"'); begin' \
        '  process (clk) begin if rising_edge(clk) then' \
        '    if rst = '"'"'1'"'"' then cnt <= (others => '"'"'0'"'"'); elsif en = '"'"'1'"'"' then cnt <= cnt + 1; end if;' \
        '  end if; end process; q <= std_logic_vector(cnt); end architecture;' \
        > counter.vhd \
    && yosys -V \
    && yosys -q -m ghdl -p "ghdl --std=08 counter.vhd -e counter; synth -top counter; tee -o /dev/stdout stat" \
    && rm -rf /tmp/yosys-test

# Zurück zum Entwicklungsbenutzer des Basis-Images (fpga-env, UID/GID 1000)
USER 1000:1000
WORKDIR /workspaces