def _find_shell(repository_ctx):
  bazel_sh = repository_ctx.os.environ.get("BAZEL_SH")
  if bazel_sh:
    if (bazel_sh.endswith("bash")
        or bazel_sh.endswith("bash.exe")
        or bazel_sh.endswith("sh")):
      return bazel_sh, "-c"
    else:
      return bazel_sh, None
  else:
    if repository_ctx.os.name.startswith("windows"):
      bash = repository_ctx.which("bash.exe")
      if bash:
        lbash = bash.lower()
        if "msys" in lbash and "windows" not in lbash:
          return bash, "-c"
    else:
      bash = repository_ctx.which("bash")
      if bash:
        return bash, "-c"

  return None, None


def _quote_or_none(v):
  if v:
    return "\"" + str(v) + "\""
  else:
    return None


def _local_shell_autoconfig_impl(repository_ctx):
  shell_path, run_command_flag = _find_shell(repository_ctx)
  build_file = [
      'load(',
      '    "@bazel_tools//tools/shell:build_rules.bzl",',
      '    "decl_toolchain",',
      '    "shell_toolchain",',
      ')',
      '',
      'shell_toolchain(',
      '    name = "auto_configured_shell",',
      '    shell_path = %s,' % _quote_or_none(shell_path),
      '    run_command_flag = %s,' % _quote_or_none(run_command_flag),
      '    visibility = ["//visibility:private"],',
      ')',
      '',
      'decl_toolchain(',
      '    name = "toolchain",',
      '    rule = ":auto_configured_shell",',
      ')']

  repository_ctx.file("BUILD", "\n".join(build_file));


local_shell_config = repository_rule(
    implementation = _local_shell_autoconfig_impl,
    local = True,
    environ = ["BAZEL_SH"],
    attrs = {
        "decl": attr.label(providers = [platform_common.ToolchainInfo]),
        "debug": attr.bool(),
    },
)
