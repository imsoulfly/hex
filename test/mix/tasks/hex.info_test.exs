defmodule Mix.Tasks.Hex.InfoTest do
  use HexTest.Case
  @moduletag :integration

  defmodule Simple do
    def project do
      [
        app: :simple,
        version: "0.1.0",
        deps: [
          {:ecto, "0.2.0"}
        ]
      ]
    end
  end

  test "package" do
    Mix.Tasks.Hex.Info.run(["ex_doc"])
    assert_received {:mix_shell, :info, ["Some description\n"]}
    assert_received {:mix_shell, :info, ["Config: {:ex_doc, \"~> 0.1.0\"}"]}
    assert_received {:mix_shell, :info, ["Releases: 0.1.0, 0.1.0-rc1, 0.0.1\n"]}

    Mix.Tasks.Hex.Info.run(["no_package"])
    assert_received {:mix_shell, :error, ["No package with name no_package"]}
  end

  test "locked package" do
    Mix.Project.push(Simple)

    in_tmp(fn ->
      Hex.State.put(:home, File.cwd!())
      Mix.Task.run("deps.get")
      Mix.Task.clear()

      Mix.Tasks.Hex.Info.run(["ecto"])
      assert_received {:mix_shell, :info, ["Some description\n"]}
      assert_received {:mix_shell, :info, ["Locked version: 0.2.0"]}
      assert_received {:mix_shell, :info, ["Config: {:ecto, \"~> 3.3\"}"]}
      assert_received {:mix_shell, :info, ["Releases: 3.3.2, 3.3.1, 0.2.1, 0.2.0\n"]}
    end)
  after
    purge([
      Ecto.NoConflict.MixProject,
      Postgrex.NoConflict.MixProject,
      Ex_doc.NoConflict.MixProject
    ])
  end

  test "package with retired release" do
    Mix.Tasks.Hex.Info.run(["tired"])
    assert_received {:mix_shell, :info, ["Releases: 0.2.0, 0.1.0 (retired)\n"]}
  end

  test "package with --organization flag" do
    in_tmp(fn ->
      Hex.State.put(:cache_home, tmp_path())

      send(self(), {:mix_shell_input, :yes?, true})
      send(self(), {:mix_shell_input, :prompt, "user"})
      # account password
      send(self(), {:mix_shell_input, :prompt, "hunter42"})
      # local password
      send(self(), {:mix_shell_input, :prompt, "hunter42"})
      # confirm
      send(self(), {:mix_shell_input, :prompt, "hunter42"})

      Mix.Tasks.Hex.Info.run(["foo", "--organization", "testorg"])

      assert_received {:mix_shell, :info,
                       ["Config: {:foo, \"~> 0.1.0\", organization: \"testorg\"}"]}
    end)
  end

  test "release" do
    Mix.Tasks.Hex.Info.run(["ex_doc", "0.0.1"])
    assert_received {:mix_shell, :info, ["Config: {:ex_doc, \"~> 0.0.1\"}"]}

    Mix.Tasks.Hex.Info.run(["ex_doc", "0.1.0-rc1"])
    assert_received {:mix_shell, :info, ["Config: {:ex_doc, \"~> 0.1.0-rc1\"}"]}

    Mix.Tasks.Hex.Info.run(["ex_doc", "1.2.3"])
    assert_received {:mix_shell, :error, ["No release with name ex_doc 1.2.3"]}
  end

  test "prints publisher info for releases" do
    Mix.Tasks.Hex.Info.run(["ex_doc", "0.0.1"])
    assert_received {:mix_shell, :info, ["Published by: user (user@mail.com)"]}
  end

  test "latest_release/2" do
    import Mix.Tasks.Hex.Info, only: [latest_release: 2]

    v1_1_0_rc1 = %{"version" => "1.1.0-rc.1"}
    v1_1_0_rc0 = %{"version" => "1.1.0-rc.0"}
    v1_0_1 = %{"version" => "1.0.1"}
    v1_0_0 = %{"version" => "1.0.0"}

    assert latest_release([v1_0_1, v1_0_0], []) == v1_0_1

    assert latest_release([v1_1_0_rc1, v1_0_0], []) == v1_0_0
    assert latest_release([v1_1_0_rc1, v1_1_0_rc0], []) == v1_1_0_rc1

    assert latest_release([v1_0_1, v1_0_0], ["1.0.1"]) == v1_0_0
    assert latest_release([v1_0_1, v1_0_0], ["1.0.1", "1.0.0"]) == v1_0_1
  end
end
