defmodule Ash.Type.TupleTest do
  use ExUnit.Case, async: true

  alias Ash.Test.Domain, as: Domain

  defmodule TupleWithFields do
    use Ash.Type.NewType,
      subtype_of: :tuple,
      constraints: [
        fields: [
          foo: [type: :string, allow_nil?: false]
        ]
      ]
  end

  defmodule Post do
    @moduledoc false
    use Ash.Resource, domain: Domain, data_layer: Ash.DataLayer.Ets

    ets do
      private?(true)
    end

    actions do
      default_accept :*
      defaults [:read, :destroy, create: :*, update: :*]
    end

    attributes do
      uuid_primary_key :id

      attribute :metadata_type, TupleWithFields do
        public? true
      end

      attribute :metadata, :tuple do
        public? true

        constraints fields: [
                      foo: [type: :string, allow_nil?: false],
                      integer_min_0: [type: :integer, constraints: [min: 0]]
                    ]
      end
    end
  end

  test "it handles valid tuples" do
    changeset =
      Post
      |> Ash.Changeset.for_create(:create, %{
        metadata: {"bar", 1},
        metadata_type: {"bar"}
      })

    assert changeset.valid?
  end

  test "allow_nil? is true by default" do
    changeset =
      Post
      |> Ash.Changeset.for_create(:create, %{
        metadata: {"bar", "2"}
      })

    assert changeset.valid?

    assert changeset.attributes == %{
             metadata: {"bar", 2}
           }
  end

  test "keys that can be nil don't need to be there" do
    changeset =
      Post
      |> Ash.Changeset.for_create(:create, %{
        metadata: {
          "bar",
          nil
        }
      })

    assert changeset.valid?
  end

  test "keys that can not be nil need to be there" do
    changeset =
      Post
      |> Ash.Changeset.for_create(:create, %{
        metadata: {nil, 1}
      })

    refute changeset.valid?

    assert [
             %Ash.Error.Changes.InvalidAttribute{
               field: :foo,
               message: "value must not be nil",
               private_vars: nil,
               value: {nil, 1},
               bread_crumbs: [],
               vars: [],
               path: [:metadata]
             }
           ] = changeset.errors
  end

  test "constraints of field types are checked" do
    changeset =
      Post
      |> Ash.Changeset.for_create(:create, %{
        metadata: {"hello", -1}
      })

    refute changeset.valid?

    assert [
             %Ash.Error.Changes.InvalidAttribute{
               field: :integer_min_0,
               message: "must be more than or equal to %{min}",
               private_vars: nil,
               value: {"hello", -1},
               bread_crumbs: [],
               vars: [min: 0],
               path: [:metadata]
             }
           ] = changeset.errors
  end

  test "values are casted before checked" do
    changeset =
      Post
      |> Ash.Changeset.for_create(
        :create,
        %{
          metadata: {"", "2"}
        }
      )

    refute changeset.valid?

    assert [
             %Ash.Error.Changes.InvalidAttribute{
               field: :foo,
               message: "value must not be nil",
               private_vars: nil,
               value: {"", "2"},
               bread_crumbs: [],
               vars: [],
               path: [:metadata]
             }
           ] = changeset.errors
  end
end
