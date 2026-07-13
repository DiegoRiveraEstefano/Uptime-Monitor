defmodule UptimeMonitor.StatusPages do
  @moduledoc """
  The StatusPages context. Handles CRUD operations for public status pages.
  """

  import Ecto.Query, warn: false

  alias UptimeMonitor.Repo
  alias UptimeMonitor.StatusPages.StatusPage
  alias UptimeMonitor.Accounts.Tenant

  @doc """
  Lists all status pages for a tenant.
  """
  @spec list_status_pages(pos_integer()) :: [StatusPage.t()]
  def list_status_pages(tenant_id) do
    StatusPage
    |> where([s], s.tenant_id == ^tenant_id)
    |> order_by([s], asc: s.title)
    |> Repo.all()
  end

  @doc """
  Gets a single status page scoped to a tenant.
  """
  @spec get_status_page(pos_integer(), pos_integer()) ::
          {:ok, StatusPage.t()} | {:error, :not_found}
  def get_status_page(tenant_id, id) do
    case Repo.one(from s in StatusPage, where: s.id == ^id and s.tenant_id == ^tenant_id) do
      nil -> {:error, :not_found}
      status_page -> {:ok, status_page}
    end
  end

  @doc """
  Gets a status page by slug. If it's private, requires authentication checks outer-scope.
  """
  @spec get_status_page_by_slug(String.t()) :: {:ok, StatusPage.t()} | {:error, :not_found}
  def get_status_page_by_slug(slug) when is_binary(slug) do
    case Repo.get_by(StatusPage, slug: slug) do
      nil -> {:error, :not_found}
      status_page -> {:ok, status_page}
    end
  end

  @doc """
  Creates a status page.
  """
  @spec create_status_page(Tenant.t(), map()) :: {:ok, StatusPage.t()} | {:error, any()}
  def create_status_page(%Tenant{} = tenant, attrs) do
    %StatusPage{tenant_id: tenant.id}
    |> StatusPage.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a status page configuration.
  """
  @spec update_status_page(Tenant.t(), StatusPage.t(), map()) ::
          {:ok, StatusPage.t()} | {:error, any()}
  def update_status_page(%Tenant{} = tenant, %StatusPage{} = status_page, attrs) do
    if status_page.tenant_id == tenant.id do
      status_page
      |> StatusPage.changeset(attrs)
      |> Repo.update()
    else
      {:error, :unauthorized}
    end
  end

  @doc """
  Deletes a status page.
  """
  @spec delete_status_page(Tenant.t(), StatusPage.t()) :: {:ok, StatusPage.t()} | {:error, any()}
  def delete_status_page(%Tenant{} = tenant, %StatusPage{} = status_page) do
    if status_page.tenant_id == tenant.id do
      Repo.delete(status_page)
    else
      {:error, :unauthorized}
    end
  end
end
