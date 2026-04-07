# flake.nix, run with `nix develop`
{
    description = "CUDA development environment";
    outputs = {
        self,
        nixpkgs,
        }: let
            system = "x86_64-linux";
            pkgs = import nixpkgs {
                inherit system;
                config.allowUnfree = true;
                config.cudaSupport = true;
                config.cudaVersion = "12";
            };
            # Change according to the driver used: stable, beta
            nvidiaPackage = pkgs.linuxPackages.nvidiaPackages.stable;
        in {
            # alejandra is a nix formatter with a beautiful output
            formatter."${system}" = nixpkgs.legacyPackages.${system}.alejandra;
            devShells.${system}.default = pkgs.mkShell {
                buildInputs = with pkgs; [
                    ffmpeg
                    fmt.dev
                    cudaPackages.cuda_cudart
                    cudatoolkit
                    nvidiaPackage
                    cudaPackages.cudnn
                    libGLU
                    libGL
                    mesa-demos
                    glew      # provides GL/glew.h
                    glfw      # provides GLFW/glfw3.h
                    libxi     # was xorg.libXi
                    libxmu    # was xorg.libXmu
                    freeglut
                    libxext   # was xorg.libXext
                    libx11    # was xorg.libX11
                    libxv     # was xorg.libXv
                    libxrandr # was xorg.libXrandr
                    zlib
                    ncurses
                    stdenv.cc
                    binutils
                    uv
                ];
                shellHook = ''
        export LD_LIBRARY_PATH=/run/opengl-driver/lib:${pkgs.glew}/lib:${pkgs.glfw}/lib:$LD_LIBRARY_PATH
        # export LD_LIBRARY_PATH="${nvidiaPackage}/lib:$LD_LIBRARY_PATH"
        export CUDA_PATH=${pkgs.cudatoolkit}
        export EXTRA_LDFLAGS="-L/lib -L${nvidiaPackage}/lib"
        export EXTRA_CCFLAGS="-I/usr/include"
        export CMAKE_PREFIX_PATH="${pkgs.fmt.dev}:$CMAKE_PREFIX_PATH"
        export PKG_CONFIG_PATH="${pkgs.fmt.dev}/lib/pkgconfig:$PKG_CONFIG_PATH"

        export C_INCLUDE_PATH="${pkgs.glew.dev}/include:${pkgs.glfw}/include:${pkgs.libglvnd.dev}/include:$C_INCLUDE_PATH"
        export CPLUS_INCLUDE_PATH="${pkgs.glew.dev}/include:${pkgs.glfw}/include:${pkgs.libglvnd.dev}/include:$CPLUS_INCLUDE_PATH"
        export LIBRARY_PATH="${pkgs.glew}/lib:${pkgs.glfw}/lib:/run/opengl-driver/lib:$LIBRARY_PATH"

        export __NV_PRIME_RENDER_OFFLOAD=1
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __VK_LAYER_NV_optimus=NVIDIA_only

        echo "CUDA + OpenGL dev shell ready (RTX 3050, sm_86)"
        '';
            };
        };
}
