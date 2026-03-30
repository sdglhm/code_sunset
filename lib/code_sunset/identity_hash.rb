module CodeSunset
  class IdentityHash
    class << self
      def digest(value)
        Digest::SHA256.hexdigest(value.to_s)
      end
    end
  end
end
