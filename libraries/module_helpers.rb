module WpCli
  module Helpers
    def url2path(url)
      return ::File.join(node['wp']['base-path'], strip_www(norm_url(url)))
    end

    def url2docroot(url)
      return ::File.join(node['wp']['base-path'], strip_www(url2host(url)))
    end

    def url2host(url)
      return url[%r{^[^/]+}]
    end

    def url2base(url)
      return url[%r{^[^/]+(/.*)}, 1]
    end

    def norm_url(url)
      return strip_scheme(url).chomp('/')
    end

    def strip_scheme(url)
      return url.gsub(%r{^(.+://)?}, '')
    end

    def strip_www(url)
      url.start_with?('www.') ? url[4..-1] : url
    end
  end
end