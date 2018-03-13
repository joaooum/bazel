def _shell_toolchain_impl(ctx):
  toolchain = platform_common.ToolchainInfo(
      shell = ctx.attr.shell_path,
      run_command_flag = ctx.attr.run_command_flag,
  )
  return [toolchain]


shell_toolchain = rule(
    implementation = _shell_toolchain_impl,
    attrs = {
        "shell_path": attr.string(),
        "run_command_flag": attr.string(),
    })


def decl_toolchain(name, rule):
  """Declare a `toolchain` rule using a `shell_toolchain` as the implementation."""
  native.toolchain(
      name = name,
      exec_compatible_with = [
          "@bazel_tools//platforms:host_platform",
      ],
      target_compatible_with = [
          "@bazel_tools//platforms:target_platform",
      ],
      toolchain = rule,
      toolchain_type = "@bazel_tools//tools/shell:shell_toolchain_type",
  )

