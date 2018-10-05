defmodule ReceiptVerifierTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExVCR.Adapter.Hackney

  alias ReceiptVerifier.ResponseData

  setup do
    ExVCR.Config.cassette_library_dir("test/fixtures/vcr_cassettes")
    :ok
  end

  describe "receipt" do
    test "valid receipt" do
      use_cassette "receipt" do
        base64_receipt = read_receipt_file("receipt")

        {:ok, %ResponseData{app_receipt: receipt}} = ReceiptVerifier.verify(base64_receipt)

        assert "1241", receipt.application_version
      end
    end
  end

  describe "auto-renewable receipt" do
    test "app receipt" do
      use_cassette "auto_renewable_receipt" do
        base64_receipt = read_receipt_file("auto_renewable_receipt")

        {:ok, result} = ReceiptVerifier.verify(base64_receipt, password: "password")

        %ResponseData{app_receipt: app_receipt} = result

        assert "1241", app_receipt.application_version
      end
    end
  end

  describe "exclude old iap receipts" do
    test "dont exclude transactions" do
      use_cassette "exclude_old_transactions_false" do
        base64_receipt = read_receipt_file("griddiary_production")

        {:ok, result} =
          ReceiptVerifier.verify(
            base64_receipt,
            exclude_old_transactions: false,
            password: "password"
          )

        assert 3 == length(result.latest_iap_receipts)
      end
    end

    test "will exclude old transactions" do
      use_cassette "exclude_old_transactions" do
        base64_receipt = read_receipt_file("griddiary_production")

        {:ok, result} =
          ReceiptVerifier.verify(
            base64_receipt,
            exclude_old_transactions: true,
            password: "password"
          )

        assert 1 == length(result.latest_iap_receipts)
      end
    end
  end

  describe "invalid receipt" do
    test "malformed receipt data" do
      use_cassette "invalid_receipt" do
        base64_receipt = "foobar"

        {:error, %ReceiptVerifier.Error{code: code, message: msg}} =
          ReceiptVerifier.verify(base64_receipt)

        assert 21002 == code
        assert "The data in the receipt-data property was malformed or missing." == msg
      end
    end
  end

  describe "environment" do
    test "production receipt in sandbox env" do
      use_cassette "production_receipt_to_sandbox" do
        base64_receipt = read_receipt_file("griddiary_production")

        {:error, %ReceiptVerifier.Error{} = err} =
          ReceiptVerifier.verify(base64_receipt, env: :sandbox)

        assert 21008 == err.code
      end
    end

    test "sandbox receipt in production env" do
      use_cassette "sandbox_receipt_to_production" do
        base64_receipt = read_receipt_file("receipt")

        {:error, %ReceiptVerifier.Error{} = err} =
          ReceiptVerifier.verify(base64_receipt, env: :production)

        assert 21007 == err.code
      end
    end

    test "sandbox receipt in auto env" do
      use_cassette "sandbox_receipt_to_auto" do
        base64_receipt = read_receipt_file("receipt")

        {:ok, result} = ReceiptVerifier.verify(base64_receipt, env: :auto)

        %ResponseData{app_receipt: app_receipt} = result

        assert "1241", app_receipt.application_version
      end
    end
  end

  defp read_receipt_file(filename) do
    "test/fixtures/receipts/#{filename}"
    |> File.read!()
    |> String.replace("\n", "")
  end
end
