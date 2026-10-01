# SPDX-FileCopyrightText: 2026 ash_affidavit contributors
#
# SPDX-License-Identifier: MIT

defmodule AshAffidavit.LimitsTest do
  use ExUnit.Case, async: false

  alias AshAffidavit.ABI
  alias AshAffidavit.Refusal

  setup_all do
    start_supervised!({AshAffidavit.Pool, size: 2})
    :ok
  end

  test "ABI request cap equals the engine registry's max_request_bytes (16 MiB)" do
    assert ABI.max_request_bytes() == AshAffidavit.registry()["limits"]["max_request_bytes"]
    assert ABI.max_request_bytes() == 16_777_216
  end

  test "an oversize request is a typed resource-limit refusal and the module stays healthy" do
    huge = String.duplicate("a", ABI.max_request_bytes() + 1)

    assert {:refused, %Refusal{code: :resource_limit, class: :blocked_resource, details: details}} =
             AshAffidavit.call(%{"op" => "commit", "payload" => huge})

    assert details.limit == ABI.max_request_bytes()
    assert details.bytes > ABI.max_request_bytes()

    # healthy afterwards: same pool, no recycle needed, real engine still answers
    assert AshAffidavit.Pool.members() != []
    assert {:ok, %{"ok" => true, "op" => "commit"}} = AshAffidavit.call(%{"op" => "commit", "payload" => "after"})
    assert {:ok, %{"ok" => true}} = AshAffidavit.capabilities()
  end

  test "a request just under the cap reaches the engine and is answered" do
    # JSON framing (op, key names, quotes) costs well under 1 KiB.
    payload = String.duplicate("a", ABI.max_request_bytes() - 1024)
    assert {:ok, %{"ok" => true, "op" => "commit"}} = AshAffidavit.call(%{"op" => "commit", "payload" => payload})
  end

  test "invalid UTF-8 in a request is refused before the engine sees it" do
    assert {:refused, %Refusal{code: :invalid_encoding}} =
             AshAffidavit.call(%{"op" => "commit", "payload" => <<0xFF, 0xFE>>})

    assert {:ok, _} = AshAffidavit.capabilities()
  end
end
