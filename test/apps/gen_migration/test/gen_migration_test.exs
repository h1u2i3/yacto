defmodule GenMigrationTest do
  use PowerAssert

  test "Yacto.Migration.Structure.diff" do
    structure_from = %Yacto.Migration.Structure{
                       fields: [:id, :name, :value],
                       source: "player",
                       types: %{id: :id, name: :string, value: :integer}
                     }
    structure_to = %Yacto.Migration.Structure{
                     autogenerate_id: {:id2, :id2, :binary_id},
                     fields: [:id, :name2, :value],
                     primary_key: [:id2],
                     source: "player",
                     types: %{id: :id, name2: :string, value: :string}
                   }
    diff = Yacto.Migration.Structure.diff(structure_from, structure_to)
    assert %{source: :not_changed,
             fields: [eq: [:id], del: [:name], ins: [:name2], eq: [:value]],
             types: %{del: %{name: :string,
                             value: :integer},
                      ins: %{name2: :string,
                             value: :string}},
             primary_key: [del: [:id], ins: [:id2]],
             autogenerate_id: {:changed, {:id, :id, :id}, {:id2, :id2, :binary_id}},
             meta: %{attrs: %{del: %{}, ins: %{}},
                     indices: %{del: %{}, ins: %{}}}} == diff
    assert Yacto.Migration.Structure.apply(structure_from, diff) == structure_to
  end

  @migrate1 """
            defmodule GenMigration.Migration20170424155528 do
              use Ecto.Migration

              def change(GenMigration.Player) do
                tablename = "player"
                create table(tablename)
                alter table(tablename) do
                  add(:inserted_at, :naive_datetime, [])
                  add(:name, :string, [])
                  add(:updated_at, :naive_datetime, [])
                  add(:value, :integer, [])
                end
              end

              def change(_other) do
                :ok
              end

              def __migration_structures__() do
                [
                  {GenMigration.Player, %Yacto.Migration.Structure{fields: [:id, :name, :value, :inserted_at, :updated_at], source: "player", types: %{id: :id, inserted_at: :naive_datetime, name: :string, updated_at: :naive_datetime, value: :integer}}},
                ]
              end

              def __migration_version__() do
                20170424155528
              end
            end
            """

  @migrate2 """
            defmodule GenMigration.Migration20170424155530 do
              use Ecto.Migration

              def change(GenMigration.Player) do
                tablename = "player2"
                rename table("player"), to: table(tablename)
                alter table(tablename) do
                  remove(:inserted_at)
                  remove(:name)
                  add(:name2, :string, [])
                  remove(:updated_at)
                  remove(:value)
                  add(:value, :string, [])
                end
              end

              def change(_other) do
                :ok
              end

              def __migration_structures__() do
                [
                  {GenMigration.Player, %Yacto.Migration.Structure{fields: [:id, :name2, :value], source: "player2", types: %{id: :id, name2: :string, value: :string}}},
                ]
              end

              def __migration_version__() do
                20170424155530
              end
            end
            """

  @migrate3 """
            defmodule GenMigration.Migration20170424155532 do
              use Ecto.Migration

              def change(GenMigration.Player) do
                tablename = "gen_migration_player3"
                rename table("player2"), to: table(tablename)
                alter table(tablename) do
                  remove(:name2)
                  add(:name3, :string, [null: false, size: 100])
                end
                create index("gen_migration_player3", [:name3, :value], [name: "name3_value_index", unique: true])
                create index("gen_migration_player3", [:value, :name3], [name: "value_name3_index"])
              end

              def change(_other) do
                :ok
              end

              def __migration_structures__() do
                [
                  {GenMigration.Player, %Yacto.Migration.Structure{fields: [:id, :name3, :value], meta: %{attrs: %{name3: %{null: false, size: 100}}, indices: %{{[:name3, :value], [unique: true]} => true, {[:value, :name3], []} => true}}, source: "gen_migration_player3", types: %{id: :id, name3: :string, value: :string}}},
                ]
              end

              def __migration_version__() do
                20170424155532
              end
            end
            """

  @migrate4 """
            defmodule GenMigration.Migration20170424155533 do
              use Ecto.Migration

              def change(GenMigration.Player) do
                drop table("gen_migration_player3")
              end

              def change(_other) do
                :ok
              end

              def __migration_structures__() do
                [
                  {GenMigration.Player, %Yacto.Migration.Structure{}},
                ]
              end

              def __migration_version__() do
                20170424155533
              end
            end
            """

  test "Yacto.Migration.GenMigration.generate_source" do
    v1 = [{GenMigration.Player, %Yacto.Migration.Structure{}, Yacto.Migration.Structure.from_schema(GenMigration.Player)}]
    v2 = [{GenMigration.Player, Yacto.Migration.Structure.from_schema(GenMigration.Player), Yacto.Migration.Structure.from_schema(GenMigration.Player2)}]
    v3 = [{GenMigration.Player, Yacto.Migration.Structure.from_schema(GenMigration.Player2), Yacto.Migration.Structure.from_schema(GenMigration.Player3)}]
    v4 = [{GenMigration.Player, Yacto.Migration.Structure.from_schema(GenMigration.Player3), %Yacto.Migration.Structure{}}]
    source = Yacto.Migration.GenMigration.generate_source(GenMigration, v1, 20170424155528)
    assert @migrate1 == source
    source = Yacto.Migration.GenMigration.generate_source(GenMigration, v2, 20170424155530)
    assert @migrate2 == source
    source = Yacto.Migration.GenMigration.generate_source(GenMigration, v3, 20170424155532)
    assert @migrate3 == source
    source = Yacto.Migration.GenMigration.generate_source(GenMigration, v4, 20170424155533)
    assert @migrate4 == source
  end

  @migrate5 """
            defmodule GenMigration.Migration20170424155528 do
              use Ecto.Migration

              def change(GenMigration.Item) do
                tablename = "gen_migration_item"
                create table(tablename)
                alter table(tablename) do
                  add(:_gen_migration_dummy, :integer, [])
                  remove(:id)
                end
                alter table(tablename) do
                  remove(:_gen_migration_dummy)
                  add(:id, :binary_id, [primary_key: true, autogenerate: true])
                  add(:name, :string, [])
                end
              end

              def change(_other) do
                :ok
              end

              def __migration_structures__() do
                [
                  {GenMigration.Item, %Yacto.Migration.Structure{autogenerate_id: {:id, :id, :binary_id}, fields: [:id, :name], source: "gen_migration_item", types: %{id: :binary_id, name: :string}}},
                ]
              end

              def __migration_version__() do
                20170424155528
              end
            end
            """
     

  test "Yacto.Migration.GenMigrationgenerate_source with dummy." do
    v1 = [{GenMigration.Item, %Yacto.Migration.Structure{}, Yacto.Migration.Structure.from_schema(GenMigration.Item)}]
    source = Yacto.Migration.GenMigration.generate_source(GenMigration, v1, 20170424155528)
    assert @migrate5 == source
  end
end
