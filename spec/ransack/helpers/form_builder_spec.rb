require 'spec_helper'

module Ransack
  module Helpers
    describe FormBuilder do

      router = ActionDispatch::Routing::RouteSet.new
      router.draw do
        resources :people
        resources :notes
        get ':controller(/:action(/:id(.:format)))'
      end

      include router.url_helpers

      # FIXME: figure out a cleaner way to get this behavior
      before do
        @controller = ActionView::TestCase::TestController.new
        @controller.instance_variable_set(:@_routes, router)
        @controller.class_eval do
          include router.url_helpers
        end

        @controller.view_context_class.class_eval do
          include router.url_helpers
        end

        @s = Person.search
        @controller.view_context.search_form_for @s do |f|
          @f = f
        end
      end

      it 'selects previously-entered time values with datetime_select' do
        @s.created_at_eq = [2011, 1, 2, 3, 4, 5]
        html = @f.datetime_select(
          :created_at_eq,
          :use_month_numbers => true,
          :include_seconds => true
          )
        %w(2011 1 2 03 04 05).each do |val|
          html.should match /<option selected="selected" value="#{val}">#{val}<\/option>/
        end
      end

      describe '#label' do

        it 'localizes attribute names' do
          html = @f.label :name_cont
          html.should match /Full Name contains/
        end

      end

      describe '#sort_link' do
        it 'sort_link for ransack attribute' do
          sort_link = @f.sort_link :name, :controller => 'people'
          if ActiveRecord::VERSION::STRING =~ /^3\.[1-2]\./
            sort_link.should match /people\?q%5Bs%5D=name\+asc/
          else
            sort_link.should match /people\?q(%5B|\[)s(%5D|\])=name\+asc/
          end
          sort_link.should match /sort_link/
          sort_link.should match /Full Name<\/a>/
        end

        it 'sort_link for common attribute' do
          sort_link = @f.sort_link :id, :controller => 'people'
          sort_link.should match /id<\/a>/
        end
      end

      describe '#submit' do

        it 'localizes :search when no default value given' do
          html = @f.submit
          html.should match /"Search"/
        end

      end

      describe '#attribute_select' do

        it 'returns ransackable attributes' do
          html = @f.attribute_select
          html.split(/\n/).
            should have(Person.ransackable_attributes.size + 1).lines
          Person.ransackable_attributes.each do |attribute|
            html.should match /<option value="#{attribute}">/
          end
        end

        it 'returns ransackable attributes for associations with :associations' do
          attributes = Person.ransackable_attributes + Article.
            ransackable_attributes.map { |a| "articles_#{a}" }
          html = @f.attribute_select(:associations => ['articles'])
          html.split(/\n/).should have(attributes.size).lines
          attributes.each do |attribute|
            html.should match /<option value="#{attribute}">/
          end
        end

        it 'returns option groups for base and associations with :associations' do
          html = @f.attribute_select(:associations => ['articles'])
          [Person, Article].each do |model|
            html.should match /<optgroup label="#{model}">/
          end
        end

      end

      describe '#predicate_select' do

        it 'returns predicates with predicate_select' do
          html = @f.predicate_select
          Predicate.names.each do |key|
            html.should match /<option value="#{key}">/
          end
        end

        it 'filters predicates with single-value :only' do
          html = @f.predicate_select :only => 'eq'
          Predicate.names.reject { |k| k =~ /^eq/ }.each do |key|
            html.should_not match /<option value="#{key}">/
          end
        end

        it 'filters predicates with multi-value :only' do
          html = @f.predicate_select only: [:eq, :lt]
          Predicate.names.reject { |k| k =~ /^(eq|lt)/ }.each do |key|
            html.should_not match /<option value="#{key}">/
          end
        end

        it 'excludes compounds when compounds: false' do
          html = @f.predicate_select :compounds => false
          Predicate.names.select { |k| k =~ /_(any|all)$/ }.each do |key|
            html.should_not match /<option value="#{key}">/
          end
        end
      end

      context 'fields used in polymorphic relations as search attributes in form' do
        before do
          @controller.view_context.search_form_for Note.search do |f|
            @f = f
          end
        end
        it 'accepts poly_id field' do
          html = @f.text_field(:notable_id_eq)
          html.should match /id=\"q_notable_id_eq\"/
        end
        it 'accepts poly_type field' do
          html = @f.text_field(:notable_type_eq)
          html.should match /id=\"q_notable_type_eq\"/
        end
      end

      describe '#condition_fields' do
        it 'returns previously-entered values' do
          @s.name_eq = "foo"
          html = ''
          @f.condition_fields do |c|
            c.attribute_fields {|a| html = a.attribute_select}
          end
          html.should match(/<option selected=\"selected\" value=\"name\"/)
        end

        it 'filters attributes in :except' do
          @s.name_eq = "foo"
          html = ''
          @f.condition_fields :except => ['name'] do |c|
            c.attribute_fields { |a| html = a.attribute_select }
          end
          html.should_not match(/<option selected=\"selected\" value=\"name\"/)
        end
      end
    end
  end
end
