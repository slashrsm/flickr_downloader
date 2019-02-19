defmodule FlickrDownloader do

  def request(operation, retry \\ 1) do
    case Flickrex.request(operation) do
      {:ok, resp} ->
        {:ok, resp}
      {:error, resp} ->
        if retry < 10 do
          Process.sleep(10000)
          request(operation, (retry + 1))
        else
          {:error, resp}
        end
    end
  end

  def auth do
    {:ok, %{body: request}} = Flickrex.Auth.request_token() |> Flickrex.request()

    {:ok, auth_url} =
      request.oauth_token
      |> Flickrex.Auth.authorize_url()
      |> Flickrex.request()

    IO.puts auth_url
    verifier = String.trim(IO.gets("Enter the token:"))

    {:ok, %{body: access}} =
      request.oauth_token
      |> Flickrex.Auth.access_token(request.oauth_token_secret, verifier)
      |> Flickrex.request()

   IO.puts "OAuth token: " <> access.oauth_token
   IO.puts "OAuth token secret: " <> access.oauth_token_secret
  end

  def get_photos do
    get_photos_not_in_set()
    get_photos_in_set()
  end

  def get_photos_in_set(page \\ 1) do 
    IO.puts "Fetching sets page: " <> Integer.to_string(page)

    {:ok, resp} = 
      Flickrex.Flickr.Photosets.get_list([page: page])
      |> request

    resp.body["photosets"]["photoset"]
      |> Enum.each(fn photoset -> FlickrDownloader.download_photos_in_set(photoset["id"], photoset["title"]["_content"]) end)

    if page < resp.body["photosets"]["pages"]  do
      get_photos_in_set(page + 1)
    end
  end

  def download_photos_in_set(photoset_id, title, page \\ 1) do
    IO.puts "Downloading photos page " <> Integer.to_string(page) <> " from set " <> title

    {:ok, resp} = 
      Flickrex.Flickr.Photosets.get_photos(photoset_id, Application.fetch_env!(:flickr_downloader, :user_id), [page: page])
      |> request

    resp.body["photoset"]["photo"]
      |> Enum.each(fn photo -> FlickrDownloader.download_photo(photo["id"], "data/" <> title) end)

    if page < resp.body["photoset"]["pages"] do
      download_photos_in_set(photoset_id, title, page + 1)
    end
  end

  def get_photos_not_in_set(page \\ 1) do
    IO.puts "Downloading 'not in set' page: " <> Integer.to_string(page)

    {:ok, resp} = 
      Flickrex.Flickr.Photos.get_not_in_set([page: page])
      |> request

    resp.body["photos"]["photo"]
      |> Enum.each(fn photo -> FlickrDownloader.download_photo(photo["id"], "data/Not in set") end)

    if page < resp.body["photos"]["pages"] do
      get_photos_not_in_set(page + 1)
    end
  end

  def download_photo(photo_id, location) do
    IO.puts "Downloading media with ID: " <> photo_id
    File.mkdir_p(location)

    {:ok, %{body: %{"photo" => photo}}} = 
      Flickrex.Flickr.Photos.get_info(photo_id)
      |> request

    {:ok, %{body: %{"sizes" => %{"size" => sizes}}}} = 
      Flickrex.Flickr.Photos.get_sizes(photo_id)
      |> request

    to_download =
      sizes 
      |> Enum.filter(fn size -> size["label"] == "Original" or size["label"] == "Video Original" end)
      |> Enum.each(fn size ->
        case size["label"] do 
          "Original" ->
            filename = 
              size["source"]
              |> String.split("/")
              |> List.last

            %HTTPoison.Response{body: image, status_code: 200} = HTTPoison.get!(size["source"], [], [timeout: 30000, recv_timeout: 30000])
            File.write!(location <> "/" <> filename, image)

          "Video Original" ->

            case HTTPoison.get!(size["source"], [], [follow_redirect: true, timeout: 30000, recv_timeout: 30000]) do
              %HTTPoison.Response{body: video, headers: headers, status_code: 200} -> 
                filename = 
                  headers
                  |> List.keyfind("Content-Disposition", 0)
                  |> elem(1)
                  |> String.split("=")
                  |> List.last

                File.write!(location <> "/" <> filename, video)

              _ -> 
                case Enum.find(sizes, fn s -> s["label"] == "Site MP4" end) do
                  nil ->
                    IO.puts "ERROR!!! Could not find Site MP4 for video: " <> photo_id

                  %{"source" => source} -> 
                    case HTTPoison.get!(source, [], [follow_redirect: true, timeout: 30000, recv_timeout: 30000]) do
                      %HTTPoison.Response{body: video, headers: headers, status_code: 200} -> 
                        filename = 
                          headers
                          |> List.keyfind("Content-Disposition", 0)
                          |> elem(1)
                          |> String.split("=")
                          |> List.last

                        File.write!(location <> "/" <> filename, video)

                      _ -> 
                        IO.puts "ERROR!!! Could not find Site MP4 for video: " <> photo_id
                    end
                end               
            end
        end
      end)
  end
end
