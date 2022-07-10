# frozen_string_literal: true

# 3-rd party
require "parslet"

class ContentType
  # ContentType string parser
  class Parser < ::Parslet::Parser
    class CharList # :nodoc:
      def initialize(list = nil)
        @list = list || yield
      end

      def -(other)
        CharList.new @list - other.to_a
      end

      def +(other)
        CharList.new @list + other.to_a
      end

      def to_a
        @list.dup
      end
      alias :to_ary :to_a

      def to_s
        @list.join
      end
      alias :to_str :to_s

      def size
        to_s.size
      end
    end

    def stri(s)
      str(s).tap { |o| o.instance_variable_set :@str, /#{Regexp.escape s}/i }
    end

    # rubocop:disable Layout/LineLength

    CHAR      = CharList.new { (0..127).to_a.map(&:chr) }
    CTLS      = CharList.new { (0..31).to_a.map(&:chr) << 127.chr }
    CR        = CharList.new { [13.chr] }
    LF        = CharList.new { [10.chr] }
    SPACE     = CharList.new { [" "] }
    HTAB      = CharList.new { [9.chr] }
    CRLF      = CharList.new { [13.chr + 10.chr] }
    DOT       = CharList.new { ["."] }
    SPECIALS  = CharList.new { ["(", ")", "<", ">", "@", ",", ";", ":", "\\", "\"", ".", "[", "]"] }
    TSPECIALS = CharList.new { SPECIALS + ["/", "?", "="] }

    rule(:quoted_pair)    { str("\\") >> match[Regexp.escape CHAR] }
    rule(:linear_ws)      { (str(CRLF).repeat(0, 1) >> (str(SPACE) | str(HTAB))).repeat(1) }
    rule(:qtext)          { match[Regexp.escape CHAR - ['"', "\\"] - CR] }
    rule(:quoted_string)  { str('"') >> (qtext | quoted_pair).repeat.as(:value) >> str('"') }
    rule(:token)          { match[Regexp.escape CHAR - SPACE - CTLS - TSPECIALS].repeat(1) }
    rule(:type_token)     { match[Regexp.escape CHAR - SPACE - CTLS - TSPECIALS + DOT].repeat(1) }
    rule(:space)          { str(SPACE) }

    # This could probably be simplified, in that as per RFC 6838 the entire expression could
    # just be `type_token`; the RFC names a partial but not exhaustive list of media type trees
    # and all of `x_token | vendor_token | prs_token` are really just `type_token`s in the first
    # place.
    rule(:x_token)        { stri("x-") >> type_token } # DEPRECATED - see RFC 6838
    rule(:vendor_token)   { stri("vnd.") >> type_token } # vendor tree - see RFC 6838
    rule(:prs_token)      { stri("prs.") >> type_token } # personal/vanity tree - see RFC 6838
    rule(:type)           { stri("application") | stri("audio") | stri("image") | stri("message") | stri("multipart") | stri("text") | stri("video") | x_token | vendor_token | prs_token }

    rule(:subtype)        { type_token }
    rule(:attribute)      { token }
    rule(:value)          { token.as(:value) | quoted_string }
    rule(:parameter)      { attribute.as(:attribute) >> str("=") >> value }
    rule(:parameters)     { space.repeat >> str(";") >> space.repeat >> parameter.as(:parameter) }
    rule(:content_type)   { type.as(:type) >> str("/") >> subtype.as(:subtype) >> parameters.repeat }
    root(:content_type)

    # rubocop:enable Layout/LineLength
  end
end
