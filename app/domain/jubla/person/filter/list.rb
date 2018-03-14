# encoding: utf-8

#  Copyright (c) 2017, Jungwacht Blauring Schweiz. This file is part of
#  hitobito and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito.

module Jubla::Person::Filter::List
  extend ActiveSupport::Concern

  included do
    alias_method_chain :accessibles, :excluded
  end

  private

  def accessibles_with_excluded
    scope = accessibles_without_excluded
    group ? scope.where.not(people: { id: excluded_people_ids }) : scope
  end

  def excluded_people_ids
    layer_type = group.layer_group.type.demodulize.underscore
    all_role_types = role_types(Group)
    alumnus_role_types = role_types(Group::AlumnusGroup)

    Person.
      joins(:roles).
      where(:"contactable_by_#{layer_type}" => false).
      where(roles: { type: alumnus_role_types }).
      where.not(roles: { type: all_role_types - alumnus_role_types }).
      pluck(:id)
  end

  def role_types(groups)
    groups.subclasses.flat_map do |group|
      group.roles.collect(&:sti_name)
    end
  end
end
