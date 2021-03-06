# encoding: UTF-8

# Copyright 2012 Twitter, Inc
# http://www.apache.org/licenses/LICENSE-2.0

require 'mustache'
require 'uglifier'
require 'coffee-script'

module TwitterCldr
  module Js
    CompiledFile = Struct.new(:source, :source_map)

    class Compiler
      attr_reader :locales

      def initialize(options = {})
        @locales = options[:locales] || TwitterCldr.supported_locales
        @features = options[:features] || implementation_renderers.keys
        @test_helpers = options[:test_helpers] || test_helper_renderers.keys
        @prerender = options[:prerender].nil? ? true : options[:prerender]
        @source_map = options[:source_map]
      end

      def compile_bundle(bundle, bundle_elements, bundle_hash, options = {})
        options[:minify] = true unless options.include?(:minify)

        contents = ""
        bundle_elements.each do |bundle_element|
          if renderer_const = bundle_hash[bundle_element]
            if bundle[:locale]
              contents << renderer_const.new(:locale => bundle[:locale], :prerender => @prerender).render
            else
              contents << renderer_const.new(:prerender => @prerender).render
            end
          end
        end

        bundle[:contents] = contents
        bundle[:source_map] = @source_map

        result = CoffeeScript.compile(bundle.render, {
          :bare => false,
          :sourceMap => @source_map
        })

        file = if @source_map
          CompiledFile.new(result["js"], result["sourceMap"])
        else
          CompiledFile.new(result)
        end

        # required alias definition that adds twitter_cldr to Twitter's static build process
        file.source.gsub!(/\/\*<<module_def>>\s+\*\//, %Q(/*-module-*/\n/*_lib/twitter_cldr_*/))
        file.source = Uglifier.compile(file.source) if options[:minify]

        file
      end

      def compile_each(options = {})
        @locales.each do |locale|
          bundle = TwitterCldr::Js::Renderers::Bundle.new
          bundle[:locale] = locale
          file = compile_bundle(bundle, @features, implementation_renderers, options)

          yield file, TwitterCldr.twitter_locale(locale)
        end
      end

      def compile_test(options = {})
        bundle = TwitterCldr::Js::Renderers::TestBundle.new
        file = compile_bundle(bundle, @test_helpers, test_helper_renderers, options)
        file.source
      end

      private

      def implementation_renderers
        @implementation_renderers ||= {
          :plural_rules                    => TwitterCldr::Js::Renderers::PluralRules::PluralRulesRenderer,
          :timespan                        => TwitterCldr::Js::Renderers::Calendars::TimespanRenderer,
          :datetime                        => TwitterCldr::Js::Renderers::Calendars::DateTimeRenderer,
          :additional_date_format_selector => TwitterCldr::Js::Renderers::Calendars::AdditionalDateFormatSelectorRenderer,
          :currencies                      => TwitterCldr::Js::Renderers::Shared::CurrenciesRenderer,
          :lists                           => TwitterCldr::Js::Renderers::Shared::ListRenderer,
          :bidi                            => TwitterCldr::Js::Renderers::Shared::BidiRenderer,
          :break_iterator                  => TwitterCldr::Js::Renderers::Shared::BreakIteratorRenderer,
          :calendar                        => TwitterCldr::Js::Renderers::Shared::CalendarRenderer,
          :code_point                      => TwitterCldr::Js::Renderers::Shared::CodePointRenderer,
          :numbering_systems               => TwitterCldr::Js::Renderers::Shared::NumberingSystemsRenderer,
          :phone_codes                     => TwitterCldr::Js::Renderers::Shared::PhoneCodesRenderer,
          :postal_codes                    => TwitterCldr::Js::Renderers::Shared::PostalCodesRenderer,
          :languages                       => TwitterCldr::Js::Renderers::Shared::LanguagesRenderer,
          :unicode_regex                   => TwitterCldr::Js::Renderers::Shared::UnicodeRegexRenderer,
          :territories_containment         => TwitterCldr::Js::Renderers::Shared::TerritoriesContainmentRenderer,
          :number_parser                   => TwitterCldr::Js::Renderers::Parsers::NumberParser,
          :component                       => TwitterCldr::Js::Renderers::Parsers::ComponentRenderer,
          :literal                         => TwitterCldr::Js::Renderers::Parsers::LiteralRenderer,
          :unicode_string                  => TwitterCldr::Js::Renderers::Parsers::UnicodeStringRenderer,
          :character_class                 => TwitterCldr::Js::Renderers::Parsers::CharacterClassRenderer,
          :character_range                 => TwitterCldr::Js::Renderers::Parsers::CharacterRangeRenderer,
          :character_set                   => TwitterCldr::Js::Renderers::Parsers::CharacterSetRenderer,
          :symbol_table                    => TwitterCldr::Js::Renderers::Parsers::SymbolTableRenderer,
          :parser                          => TwitterCldr::Js::Renderers::Parsers::ParserRenderer,
          :segmentation_parser             => TwitterCldr::Js::Renderers::Parsers::SegmentationParserRenderer,
          :unicode_regex_parser            => TwitterCldr::Js::Renderers::Parsers::UnicodeRegexParserRenderer,
          :token                           => TwitterCldr::Js::Renderers::Tokenizers::TokenRenderer,
          :composite_token                 => TwitterCldr::Js::Renderers::Tokenizers::CompositeTokenRenderer,
          :tokenizer                       => TwitterCldr::Js::Renderers::Tokenizers::TokenizerRenderer,
          :segmentation_tokenizer          => TwitterCldr::Js::Renderers::Tokenizers::SegmentationTokenizerRenderer,
          :unicode_regex_tokenizer         => TwitterCldr::Js::Renderers::Tokenizers::UnicodeRegexTokenizerRenderer,
          :rbnf_tokenizer                  => TwitterCldr::Js::Renderers::Tokenizers::RBNFTokenizerRenderer,
          :number_tokenizer                => TwitterCldr::Js::Renderers::Tokenizers::NumberTokenizerRenderer,
          :pattern_tokenizer               => TwitterCldr::Js::Renderers::Tokenizers::PatternTokenizerRenderer,
          :numbers                         => TwitterCldr::Js::Renderers::Numbers::NumbersRenderer,
          :rbnf                            => TwitterCldr::Js::Renderers::Numbers::RBNF::RBNFRenderer,
          :number_data_reader              => TwitterCldr::Js::Renderers::Numbers::RBNF::NumberDataReaderRenderer,
          :rbnf_formatters                 => TwitterCldr::Js::Renderers::Numbers::RBNF::FormattersRenderer,
          :rbnf_rule                       => TwitterCldr::Js::Renderers::Numbers::RBNF::RuleRenderer,
          :rbnf_rule_group                 => TwitterCldr::Js::Renderers::Numbers::RBNF::RuleGroupRenderer,
          :rbnf_rule_set                   => TwitterCldr::Js::Renderers::Numbers::RBNF::RuleSetRenderer,
          :rbnf_substitution               => TwitterCldr::Js::Renderers::Numbers::RBNF::SubstitutionRenderer,
          :rbnf_rule_parser                => TwitterCldr::Js::Renderers::Numbers::RBNF::RuleParserRenderer,
          :plural                          => TwitterCldr::Js::Renderers::Numbers::RBNF::PluralRenderer,
          :range                           => TwitterCldr::Js::Renderers::Utils::RangeRenderer,
          :range_set                       => TwitterCldr::Js::Renderers::Utils::RangeSetRenderer,
          :code_points                     => TwitterCldr::Js::Renderers::Utils::CodePointsRenderer
        }
      end

      def test_helper_renderers
        @test_helper_renderers ||= {
          :rbnf                            => TwitterCldr::Js::Renderers::TestHelpers::RBNFHelperRenderer,
          :plural_rules                    => TwitterCldr::Js::Renderers::TestHelpers::PluralRulesHelperRenderer,
          :numbers                         => TwitterCldr::Js::Renderers::TestHelpers::NumbersHelperRenderer
        }
      end

    end
  end
end
