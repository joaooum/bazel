---
layout: documentation
title: Installing Bazel on Windows
---

# <a name="windows"></a>Installing Bazel on Windows

Supported Windows platforms:

*   64-bit Windows 7 or higher, or equivalent Windows Server versions.

### Installation

1.  Download and install [MSYS2](https://msys2.github.io/).

2.  Download the [latest Bazel binary](https://github.com/bazelbuild/bazel/releases).

    No installation required, just run the binary from PowerShell or `cmd.exe`.

#### Other ways to get Bazel

*   [Compile Bazel from source](install-compile-source.html)

*   Install using [Chocolatey](https://chocolatey.org)

    Install the latest Bazel and dependencies:

    ```sh
    choco install bazel
    ```

    See [Chocolatey package maintenance guide](https://bazel.build/windows-chocolatey-maintenance.html) for more
information.

#### Troubleshooting

*   Bazel won't start.

    -   **Incompatible Windows version**.
    
        Check the <a href="https://msdn.microsoft.com/en-us/library/windows/desktop/ms724832(v=vs.85).aspx">version table</a>. Bazel requires 64-bit Windows 7 or higher, or equivalent Windows Server versions. 32-bit Windows is not supported.

    -   **"The application was unable to start correctly (0xc000007b)." error**
    
        Install the [Microsoft Visual C++ Redistributable for Visual Studio 2015](https://www.microsoft.com/en-us/download/details.aspx?id=48145).
        
    -   **MSVCP140.DLL is missing** or **VCRUNTIME140.DLL is missing**
    
        Install the [Microsoft Visual C++ Redistributable for Visual Studio 2015](https://www.microsoft.com/en-us/download/details.aspx?id=48145).

