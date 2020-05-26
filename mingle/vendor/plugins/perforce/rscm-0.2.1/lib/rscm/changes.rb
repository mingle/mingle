#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

require 'xmlrpc/utils'
require 'rscm/time_ext'

module RSCM

  # A collection of ChangeSet.
  class ChangeSets
    include Enumerable
    include XMLRPC::Marshallable

    attr_reader :changesets

    def initialize(changesets=[])
      @changesets = changesets
    end
    
    # Accepts a visitor that will receive callbacks while
    # iterating over this instance's internal structure.
    # The visitor should respond to the following methods:
    #
    # * visit_changesets(changesets)
    # * visit_changeset(changeset)
    # * visit_change(change)
    #
    def accept(visitor)
      visitor.visit_changesets(self)
      self.each{|changeset| changeset.accept(visitor)}
    end

    def [](change)
      @changesets[change]
    end

    def each(&block)
      @changesets.each(&block)
    end
    
    def reverse
      ChangeSets.new(@changesets.dup.reverse)
    end
    
    def length
      @changesets.length
    end

    def ==(other)
      return false if !other.is_a?(self.class)
      @changesets == other.changesets
    end
    
    def empty?
      @changesets.empty?
    end
    
    # The set of developers that contributed to all of the contained ChangeSet s.
    def developers
      result = []
      each do |changeset|
        result << changeset.developer unless result.index(changeset.developer)
      end
      result
    end
    
    # The latest ChangeSet (with the latest time)
    # or nil if there are none.
    def latest
      result = nil
      each do |changeset|
        result = changeset if result.nil? || result.time < changeset.time
      end
      result
    end

    # Adds a Change or a ChangeSet.
    # If the argument is a Change and no corresponding ChangeSet exists,
    # a new ChangeSet is created, added, and the Change is added to that ChangeSet -
    # and then finally the newly created ChangeSet is returned.
    # Otherwise nil is returned.
    def add(change_or_changeset)
      if(change_or_changeset.is_a?(ChangeSet))
        @changesets << change_or_changeset
        return change_or_changeset
      else
        changeset = @changesets.find { |a_changeset| a_changeset.can_contain?(change_or_changeset) }
        if(changeset.nil?)
          changeset = ChangeSet.new
          @changesets << changeset
          changeset << change_or_changeset
          return changeset
        end
        changeset << change_or_changeset
        return nil
      end
    end
    
    def push(*change_or_changesets)
      change_or_changesets.each { |change_or_changeset| self << (change_or_changeset) }
      self
    end

    # The most recent time of all the ChangeSet s.
    def time
      time = nil
      changesets.each do |changeset|
        time = changeset.time if @time.nil? || @time < changeset.time
      end
      time
    end

    # Sorts the changesets according to time
    def sort!
      @changesets.sort!
      self
    end

  end

  # Represents a collection of Change that were committed at the same time.
  # Non-transactional SCMs (such as CVS and StarTeam) emulate ChangeSet
  # by grouping Change s that were committed by the same developer, with the
  # same commit message, and within a "reasonably" small timespan.
  class ChangeSet
    include Enumerable
    include XMLRPC::Marshallable

    attr_reader :changes
    attr_accessor :revision
    attr_accessor :developer
    attr_accessor :message
    attr_accessor :time

    def initialize(changes=[])
      @changes = changes
    end
    
    def accept(visitor)
      visitor.visit_changeset(self)
      @changes.each{|change| change.accept(visitor)}
    end

    def << (change)
      @changes << change
      self.time = change.time if self.time.nil? || self.time < change.time unless change.time.nil?
      self.developer = change.developer if change.developer
      self.message = change.message if change.message
    end

    def [] (change)
      @changes[change]
    end

    def each(&block)
      @changes.each(&block)
    end
    
    def length
      @changes.length
    end

    def time=(t)
      raise "time must be a Time object - it was a #{t.class.name} with the string value #{t}" unless t.is_a?(Time)
      raise "can't set time to an inferiour value than the previous value" if @time && (t < @time)
      @time = t
    end
    
    def ==(other)
      return false if !other.is_a?(self.class)
      @changes == other.changes
    end

    def <=>(other)
      @time <=> other.time
    end

    # Whether this instance can contain a Change. Used
    # by non-transactional SCMs.
    def can_contain?(change)
      self.developer == change.developer &&
      self.message == change.message &&
      (self.time - change.time).abs < 60
    end

    # String representation that can be used for debugging.
    def to_s
      result = "#{revision} | #{developer} | #{time} | #{message}\n"
      self.each do |change|
        result << " " << change.to_s << "\n"
      end
      result
    end
    
    # Returns the identifier of the changeset. This is the revision 
    # (if defined) or an UTC time if revision is undefined.
    def identifier
      @revision || @time
    end
    
  end

  # Represents a change to an individual file.
  class Change
    include XMLRPC::Marshallable

    MODIFIED = "MODIFIED"
    DELETED = "DELETED"
    ADDED = "ADDED"
    MOVED = "MOVED"
    
    attr_accessor :status
    attr_accessor :path
    attr_accessor :previous_revision
    attr_accessor :revision

    # TODO: Remove redundant attributes that are in ChangeSet
    attr_accessor :developer
    attr_accessor :message
    # This is a UTC ruby time
    attr_accessor :time
    
    def initialize(path=nil, status=nil, developer=nil, message=nil, revision=nil, time=nil)
      @path, @developer, @message, @revision, @time, @status = path, developer, message, revision, time, status
    end
  
    def accept(visitor)
      visitor.visit_change(self)
    end

    def to_s
      "#{path} | #{revision}"
    end

    def developer=(developer)
      raise "can't be null" if developer.nil?
      @developer = developer
    end
    
    def message=(message)
      raise "can't be null" if message.nil?
      @message = message
    end

    def path=(path)
      raise "can't be null" if path.nil?
      @path = path
    end

    def revision=(revision)
      raise "can't be null" if revision.nil?
      @revision = revision
    end

    def time=(time)
      raise "time must be a Time object" unless time.is_a?(Time)
      @time = time
    end

    def ==(other)
      return false if !other.is_a?(self.class)
      self.path == other.path &&
      self.developer == other.developer &&
      self.message == other.message &&
      self.revision == other.revision &&
      self.time == other.time
    end
    
  end

end
