defmodule MigratorTest do
  use PowerAssert

  test "run migration" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    {:ok, _} = Migrator.Repo0.start_link()

    v1 = [
      {Migrator.Player, %Yacto.Migration.Structure{},
       Yacto.Migration.Structure.from_schema(Migrator.Player)}
    ]

    v2 = [
      {Migrator.Player, Yacto.Migration.Structure.from_schema(Migrator.Player),
       Yacto.Migration.Structure.from_schema(Migrator.Player2)}
    ]

    v3 = [
      {Migrator.Player, Yacto.Migration.Structure.from_schema(Migrator.Player2),
       Yacto.Migration.Structure.from_schema(Migrator.Player3)}
    ]

    try do
      for {v, version, preview_version, save_file, load_files} <- [
            {v1, 20_170_424_162_530, nil, "mig_1.exs", ["mig_1.exs"]},
            {v2, 20_170_424_162_533, 20_170_424_162_530, "mig_2.exs", ["mig_1.exs", "mig_2.exs"]},
            {v3, 20_170_424_162_534, 20_170_424_162_533, "mig_3.exs",
             ["mig_1.exs", "mig_2.exs", "mig_3.exs"]}
          ] do
        source =
          Yacto.Migration.GenMigration.generate_source(Migrator, v, version, preview_version)

        File.write!(save_file, source)
        migrations = Yacto.Migration.Util.load_migrations(load_files)

        schemas = Yacto.Migration.Util.get_all_schema(:migrator)
        :ok = Yacto.Migration.Migrator.up(:migrator, Migrator.Repo0, schemas, migrations)
      end
    after
      File.rm("mig_1.exs")
      File.rm("mig_2.exs")
      File.rm("mig_3.exs")
      Code.unload_files(["mig_1.exs"])
      Code.unload_files(["mig_2.exs"])
      Code.unload_files(["mig_3.exs"])
    end

    player = %Migrator.Player3{value: "bar", text: ""}
    player = Migrator.Repo0.insert!(player)

    assert [player] == Migrator.Repo0.all(Migrator.Player3)

    expect = """
    CREATE TABLE `migrator_player3` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `value` varchar(255) DEFAULT NULL,
      `name3` varchar(100) NOT NULL DEFAULT 'hage',
      `text_data` text NOT NULL,
      PRIMARY KEY (`id`),
      UNIQUE KEY `name3_value_index` (`name3`,`value`),
      KEY `value_name3_index` (`value`,`name3`)
    ) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8
    """

    actual =
      Ecto.Adapters.SQL.query!(
        Migrator.Repo0,
        "SHOW CREATE TABLE #{Migrator.Player3.__schema__(:source)}",
        []
      ).rows
      |> Enum.at(0)
      |> Enum.at(1)

    assert String.trim_trailing(expect) == actual
  end

  test "run migration 2" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    {:ok, _} = Migrator.Repo0.start_link()

    v1 = [
      {Migrator.Player, %Yacto.Migration.Structure{},
       Yacto.Migration.Structure.from_schema(Migrator.Player)}
    ]

    v2 = [
      {Migrator.Player, Yacto.Migration.Structure.from_schema(Migrator.Player),
       Yacto.Migration.Structure.from_schema(Migrator.Player2)}
    ]

    source = Yacto.Migration.GenMigration.generate_source(Migrator, v1, 20_170_424_162_530, nil)
    File.write!("migration_test_1.exs", source)

    source =
      Yacto.Migration.GenMigration.generate_source(
        Migrator,
        v2,
        20_170_424_162_533,
        20_170_424_162_530
      )

    File.write!("migration_test_2.exs", source)

    try do
      migrations =
        Yacto.Migration.Util.load_migrations(["migration_test_1.exs", "migration_test_2.exs"])

      schemas = Yacto.Migration.Util.get_all_schema(:migrator)
      :ok = Yacto.Migration.Migrator.up(:migrator, Migrator.Repo0, schemas, migrations)
    after
      File.rm!("migration_test_1.exs")
      File.rm!("migration_test_2.exs")
      Code.unload_files(["migration_test_1.exs", "migration_test_2.exs"])
    end

    player = %Migrator.Player2{name2: "foo", value: "bar"}
    player = Migrator.Repo0.insert!(player)

    assert [player] == Migrator.Repo0.all(Migrator.Player2)
  end

  test "Yacto.Migration.Migrator.migrate" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir(:migrator))
    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir_for_gen())

    Mix.Task.rerun("yacto.gen.migration", [])
    Mix.Task.rerun("yacto.migrate", ["--repo", "Migrator.Repo0", "--app", "migrator"])

    player = %Migrator.Player{name: "foo", value: 100}
    player = Migrator.Repo0.insert!(player)
    player = Map.drop(player, [:inserted_at, :updated_at])

    assert [player] ==
             Enum.map(
               Migrator.Repo0.all(Migrator.Player),
               &Map.drop(&1, [:inserted_at, :updated_at])
             )

    Mix.Task.rerun("yacto.migrate", ["--repo", "Migrator.Repo1"])

    player2 = %Migrator.Player2{name2: "foo", value: "bar"}
    player2 = Migrator.Repo1.insert!(player2)
    assert [player2] == Migrator.Repo1.all(Migrator.Player2)

    item = %Migrator.Item{name: "item"}
    item = Migrator.Repo1.insert!(item)
    assert [item] == Migrator.Repo1.all(Migrator.Item)

    # nothing is migrated
    Mix.Task.rerun("yacto.migrate", ["--repo", "Migrator.Repo1"])
  end

  test "Migrator.UnsignedBigInteger" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir(:migrator))
    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir_for_gen())

    Mix.Task.rerun("yacto.gen.migration", [])
    Mix.Task.rerun("yacto.migrate", ["--repo", "Migrator.Repo1", "--app", "migrator"])

    bigint = %Migrator.UnsignedBigInteger{user_id: 12_345_678_901_234_567_890}
    bigint = Migrator.Repo1.insert!(bigint)
    assert [bigint] == Migrator.Repo1.all(Migrator.UnsignedBigInteger)
  end

  test "Migrator.CustomPrimaryKey" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir(:migrator))
    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir_for_gen())

    Mix.Task.rerun("yacto.gen.migration", [])
    Mix.Task.rerun("yacto.migrate", ["--repo", "Migrator.Repo1", "--app", "migrator"])

    pk = String.duplicate("a", 10)
    record = %Migrator.CustomPrimaryKey{name: "1234"}
    record = Migrator.Repo1.insert!(record)
    assert pk == record.id
    assert [record] == Migrator.Repo1.all(Migrator.CustomPrimaryKey)
  end

  test "Migrator.Coin" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir(:migrator))
    _ = File.rm_rf(Yacto.Migration.Util.get_migration_dir_for_gen())

    Mix.Task.rerun("yacto.gen.migration", [])
    Mix.Task.rerun("yacto.migrate", ["--app", "migrator"])

    record = %Migrator.Coin{}
    record = Migrator.Repo1.insert!(record)
    assert record.type == :common_coin
  end

  test "フィールドの削除とインデックスの削除が同時に行われた場合に正しくマイグレーションできる" do
    Mix.Task.rerun("ecto.drop")
    Mix.Task.rerun("ecto.create")

    {:ok, _} = Migrator.Repo1.start_link()

    v1 = [
      {Migrator.DropFieldWithIndex, %Yacto.Migration.Structure{},
       Yacto.Migration.Structure.from_schema(Migrator.DropFieldWithIndex)}
    ]

    v2 = [
      {Migrator.DropFieldWithIndex,
       Yacto.Migration.Structure.from_schema(Migrator.DropFieldWithIndex),
       Yacto.Migration.Structure.from_schema(Migrator.DropFieldWithIndex2)}
    ]

    try do
      for {v, version, preview_version, save_file, load_files} <- [
            {v1, 20_170_424_162_530, nil, "mig_1.exs", ["mig_1.exs"]},
            {v2, 20_170_424_162_533, 20_170_424_162_530, "mig_2.exs", ["mig_1.exs", "mig_2.exs"]}
          ] do
        source =
          Yacto.Migration.GenMigration.generate_source(Migrator, v, version, preview_version)

        File.write!(save_file, source)
        migrations = Yacto.Migration.Util.load_migrations(load_files)

        schemas = Yacto.Migration.Util.get_all_schema(:migrator)
        :ok = Yacto.Migration.Migrator.up(:migrator, Migrator.Repo1, schemas, migrations)
      end
    after
      File.rm("mig_1.exs")
      File.rm("mig_2.exs")
      Code.unload_files(["mig_1.exs"])
      Code.unload_files(["mig_2.exs"])
    end

    expect = """
    CREATE TABLE `migrator_dropfieldwithindex2` (
      `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
      `value2` varchar(255) NOT NULL,
      PRIMARY KEY (`id`),
      KEY `value2_index` (`value2`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8
    """

    actual =
      Ecto.Adapters.SQL.query!(
        Migrator.Repo1,
        "SHOW CREATE TABLE #{Migrator.DropFieldWithIndex2.__schema__(:source)}",
        []
      ).rows
      |> Enum.at(0)
      |> Enum.at(1)

    assert String.trim_trailing(expect) == actual
  end
end
