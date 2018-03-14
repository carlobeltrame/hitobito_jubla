# encoding: utf-8

#  Copyright (c) 2012-2013, Jungwacht Blauring Schweiz. This file is part of
#  hitobito_jubla and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_jubla.

require 'spec_helper'

describe Role do

  describe Group::Flock::Leader do
    subject { Group::Flock::Leader }

    it { is_expected.to be_member }
    it { is_expected.to be_visible_from_above }

    its(:permissions) { should ==  [:layer_and_below_full, :contact_data, :approve_applications] }

    it 'may be created for flock' do
      role = Fabricate.build(subject.name.to_sym, group: groups(:bern))
      expect(role).to be_valid
    end

    it 'may not be created for region' do
      role = Fabricate.build(subject.name.to_sym, group: groups(:city))
      expect(role).not_to be_valid
      expect(role).to have(1).error_on(:type)
    end
  end

  describe Group::Region::External do
    subject { Group::Region::External }

    its(:kind) { should == :external }
    it { is_expected.not_to be_member }
    it { is_expected.not_to be_visible_from_above }

    its(:permissions) { should ==  [] }

    it 'may be created for region' do
      role = Fabricate.build(subject.name.to_sym, group: groups(:city))
      expect(role).to be_valid
    end
  end


  describe '#all_types' do
    subject { Role.all_types }

    it 'starts with top most role' do
      expect(subject.first).to eq(Group::Federation::GroupAdmin)
    end

    it 'finishes with bottom most role' do
      expect(subject.last).to eq(Group::SimpleGroup::DispatchAddress)
    end
  end

  context '#create' do
    let(:group) { groups(:ch) }

    it 'cannot create role without type' do
      person = Fabricate(Group::Flock::Leader.to_s, group: groups(:bern)).person
      role = person.roles.build(type: '', group: group)
      expect(role).not_to be_valid
    end
  end

  context 'alumnus' do
    let(:group) { groups(:ch) }
    let(:alumni_group) { groups(:ch_ehemalige) }

    def self.samples
      [ %w(Group::FederalBoard::Member          federal_board -1),
        %w(Group::FederalBoard::President       federal_board -1),
        %w(Group::FederalBoard::GroupAdmin      federal_board -1),
        %w(Group::FederalBoard::External        federal_board  0),
        %w(Group::FederalBoard::DispatchAddress federal_board  0),
      ]
    end

    context 'create' do
      (samples + [%w(Group::FederalAlumnusGroup::Leader ch_ehemalige -1)]).each do |role_type, group, change|
        it "#{role_type} changes alumni members by #{change}" do
          role = Fabricate(Group::FederalAlumnusGroup::Member.to_s, group: alumni_group)
          expect do
            Fabricate(role_type, person: role.person, group: groups(group))
          end.to change { Group::FederalAlumnusGroup::Member.where(group: alumni_group).count }.by(change.to_i)
        end
      end
    end

    context 'destroy' do
      samples.each do |role_type, group, change|
        it "#{role_type} changes alumni members by #{change.to_i * -1}" do
          role = Fabricate(role_type, group: groups(group))
          role.update(created_at: Time.zone.now - Settings.role.minimum_days_to_archive.days - 1.day)
          expect do
            role.destroy
          end.to change { Group::FederalAlumnusGroup::Member.where(group: alumni_group).count }.by(change.to_i * -1)
        end
      end
    end

    context 'validations'do
      it 'does not allow creating alumnus member if active role in same layer exists' do
        person = Fabricate(Group::FederalBoard::Member.to_s, group: groups(:federal_board)).person
        role = person.roles.build(type: Group::FederalAlumnusGroup::Member.to_s, group: alumni_group)
        expect(role).not_to be_valid
        expect(role.errors.full_messages.first).to eq 'Es befinden sich noch andere aktive Rollen in diesem Layer'
      end

      it 'does allow creating alumnus member if only role in same layer is in another alumnus group' do
        group = Group::FederalAlumnusGroup.create!(name: 'other', parent: groups(:ch))
        person = Fabricate(Group::FederalAlumnusGroup::Member.to_s, group: group).person
        role = person.roles.build(type: Group::FederalAlumnusGroup::Member.to_s, group: alumni_group)
        expect(role).to be_valid
      end

      it 'allows creating alumnus member if active exists in other layer' do
        person = Fabricate(Group::Flock::Leader.to_s, group: groups(:bern)).person
        role = person.roles.build(type: Group::FederalAlumnusGroup::Member.to_s, group: alumni_group)
        expect(role).to be_valid
      end

      it 'allows creating alumnus leader if active role exists in same layer' do
        person = Fabricate(Group::FederalBoard::Member.to_s, group: groups(:federal_board)).person
        role = person.roles.build(type: Group::FederalAlumnusGroup::Leader.to_s, group: alumni_group)
        expect(role).to be_valid
      end
    end


    context 'contactable_flags' do
      include ActiveSupport::Testing::TimeHelpers

      it 'resets contactable flags when creating new alumnus role' do
        person = people(:flock_leader_bern)
        person.update(contactable_by_federation: false,
                      contactable_by_state: false,
                      contactable_by_region: false,
                      contactable_by_flock: false)

        travel_to(Time.zone.now + Settings.role.minimum_days_to_archive.days + 1.day) do
          person.roles.first.destroy
        end
        expect(person.reload).to be_contactable_by_federation
        expect(person).to be_contactable_by_state
        expect(person).to be_contactable_by_region
        expect(person).to be_contactable_by_flock
      end
    end

  end

end
