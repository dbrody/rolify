require 'rolify/adapters/base'
require 'rolify/configure'
require 'rolify/dynamic'
require 'rolify/railtie' if defined?(Rails)
require 'rolify/resource'
require 'rolify/role'

module Rolify
  extend Configure

  attr_accessor :role_cname, :adapter, :resource_adapter, :role_join_table_name, :foreign_key, :role_table_name, :strict_rolify
  @@resource_types = []

  def rolify(options = {})
    include Role
    extend Dynamic if Rolify.dynamic_shortcuts

    options.reverse_merge!({:role_cname => 'Role'})
    self.role_cname = options[:role_cname]
    self.role_table_name = self.role_cname.tableize.gsub(/\//, "_")

    default_join_table = "#{self.to_s.tableize.gsub(/\//, "_")}_#{self.role_table_name}"
    options.reverse_merge!({:role_join_table_name => default_join_table})
    self.role_join_table_name = options[:role_join_table_name]

    default_foreign_key = "#{self.to_s.demodulize.underscore}_id"
    options.reverse_merge!({:foreign_key => default_foreign_key})
    self.foreign_key = options[:foreign_key]

    # setup_for_has_and_belongs_to_many(options)
    setup_for_has_many(options)

    self.adapter = Rolify::Adapter::Base.create("role_adapter", self.role_cname, self.name)

    #use strict roles
    self.strict_rolify = true if options[:strict]
  end

  def adapter
    return self.superclass.adapter unless self.instance_variable_defined? '@adapter'
    @adapter
  end

  def resourcify(association_name = :roles, options = {})
    include Resource

    options.reverse_merge!({ :role_cname => 'Role', :dependent => :destroy })
    resourcify_options = { :class_name => options[:role_cname].camelize, :as => :resource, :dependent => options[:dependent] }
    self.role_cname = options[:role_cname]
    self.role_table_name = self.role_cname.tableize.gsub(/\//, "_")
    resourcify_options[:source_type] = self.role_cname
    has_many association_name, resourcify_options

    self.resource_adapter = Rolify::Adapter::Base.create("resource_adapter", self.role_cname, self.name)
    @@resource_types << self.name
  end

  def resource_adapter
    return self.superclass.resource_adapter unless self.instance_variable_defined? '@resource_adapter'
    @resource_adapter
  end

  def scopify
    require "rolify/adapters/#{Rolify.orm}/scopes.rb"
    extend Rolify::Adapter::Scopes
  end

  def role_class
    return self.superclass.role_class unless self.instance_variable_defined? '@role_cname'
    self.role_cname.constantize
  end

  def self.resource_types
    @@resource_types
  end

  private

  def setup_for_has_and_belongs_to_many(options)
    rolify_options = { :class_name => options[:role_cname].camelize }
    rolify_options.merge!({ :join_table => self.role_join_table_name }) if Rolify.orm == "active_record"
    rolify_options.merge!({ :foreign_key => self.foreign_key }) if Rolify.orm == "active_record"
    rolify_options.merge!(options.reject{ |k,v| ![ :before_add, :after_add, :before_remove, :after_remove, :inverse_of ].include? k.to_sym })
    has_and_belongs_to_many :roles, rolify_options
  end

  def setup_for_has_many(options)
    has_many :users_roles
    has_many :roles, through: :users_roles, source: :role, source_type: self.role_cname
  end
end
