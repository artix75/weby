module Weby

    class HTMLException < Exception
    end

    class HTML

        attr_accessor :node, :nodeset, :document

        @@prefix = 'wby'
        @@evaluation_instance = nil
        @@evaluation_binding = TOPLEVEL_BINDING
        @@use_cache = true
        @@cache = {}
        @@include_path = nil

        def initialize(obj, opts = {}, &block)
            @source = opts[:source]
            if obj.is_a? Nokogiri::XML::Node
                @node = obj
                @is_doc = obj.is_a? Nokogiri::XML::Document
                @is_fragm = obj.is_a? Nokogiri::XML::DocumentFragment
                @document = @node if @is_doc || @is_fragm
                @document ||= @node.document
            elsif obj.is_a? Nokogiri::XML::NodeSet
                @nodeset = obj
                @node = obj[0]
            elsif obj.is_a? Symbol
                @document = opts[:_doc] 
                raise_err ':_doc option is missing' if !@document
                @document = @document.document if @document.is_a?(HTML)
                if !@document.is_a?(Nokogiri::XML::DocumentFragment) && 
                   !@document.is_a?(Nokogiri::XML::Document)
                    raise_err ':_doc must be Nokogiri::XML::Document[Fragment]'
                end
                @node = Nokogiri::XML::Element.new obj.to_s, @document
                opts.delete :_doc
                opts.each{|attr, val|
                    next if val.nil?
                    @node[attr] = val
                }
                self.exec(&block) if block_given?
            elsif obj.is_a? String
                if @source && @source[/\.rb$/]
                    @node = Nokogiri::HTML::DocumentFragment.parse '' 
                    self.exec :append, obj
                else
                    @node = Nokogiri::HTML::DocumentFragment.parse obj
                end
                @document = @node
                @is_fragm = true
            end
            @document ||= (@nodeset || @node).document
            if @@use_cache && @source
                @@cache[@source] = self if !@@cache.key?(@source)
            end
        end

        def builder
            @builder ||= HTMLBuilder.new(self)
        end

        def exec(mode = :append, src = nil, &block)
            if src
                text = builder.mode(mode).instance_eval(src)
            else
                text = builder.mode(mode).instance_eval(&block)
            end
            @node.add_child text if text.is_a? String
            text
        end

        def evaluate(opts = {})
            return if !@node
            _self = opts[:self] || @@evaluation_instance
            _binding = opts[:binding] || @@evaluation_binding
            conditional_attr = "#{@@prefix}-if"
            conditionals = @node.css "*[#{conditional_attr}]"
            conditionals.each{|n|
                condition = n[conditional_attr]
                args = [condition]
                args += [@source, n.line] if @source
                if _self
                    ok = _self.instance_eval *args
                else
                    ok = _binding.eval *args
                end
                if !ok
                    n.remove
                else
                    n.remove_attribute conditional_attr
                end
            }
            imports = @node.css "#{@@prefix}-include"
            imports.each{|n|
                path = n['path'] 
                if path
                    path = resolvepath path
                    if !File.exists? path
                        line = (@source ? n.line : nil)
                        raise_err "File not found: #{path}", line
                    end
                    fragm = HTML::load path
                    next if !fragm.node
                    fragm.evaluate self: _self, binding: _binding
                    n.after fragm.node
                    n.remove
                end
            }
        end

        def append(_node = nil, &block)
            _node = _node.node if _node.is_a? HTML
            @node.add_child _node if _node
            self.exec(&block) if block_given?
            self
        end

        def append_to(_node)
            if @node
                _node = _node.node if _node.is_a? HTML
                _node.add_child(@node)
            end
            self
        end

        def prepend(_node = nil, &block)
            _node = _node.node if _node.is_a? HTML
            @node.prepend_child _node if _node
            self.exec(:prepend, &block) if block_given?
            self
        end

        def prepend_to(_node)
            if @node
                _node = _node.node if _node.is_a? HTML
                _node.prepend_child(@node)
            end
            self
        end

        def find(selector)
            self.class.new((@nodeset || @node).css(selector))
        end

        def children
            return [] if !@node
            HTML.new(@node.children)
        end

        def each(&block)
            (@nodeset || [@node]).each &block 
        end

        def parent
            self.class.new(@node.parent) if @node
        end

        def next
            if @node && (nxt = @node.next)
                self.class.new(nxt)
            end
        end

        def [](attr)
           (@node || {})[attr]
        end

        def []=(attr, val)
            if @node
                @node[attr] = val
            end
        end

        def inner_html
            return '' if !@node
            @node.inner_html
        end

        def inner_html=(html)
            @node.inner_html = html if @node
        end

        def remove
            (@nodeset || @node).remove
            self
        end

        def add_class(classname)
            (@nodeset || [@node]).each{|n| add_class_to(n, classname)}
            self
        end

        def remove_class(classname)
            (@nodeset || [@node]).each{|n| remove_class_from(n, classname)}
            self
        end

        def style(*args)
            argl = args.length
            _node = @node || {}
            css = (_node['style']) || ''
            hash = parse_css css
            return hash if argl.zero?
            if argl == 1
                arg = args[0]
                if hashlike? arg
                    return if !@node
                    arg.each{|prop, val|
                        hash[prop] = val
                    }
                    @node['style'] = hash_to_css(hash)
                    return self
                else
                    return hash[arg.to_s]
                end
            else
                prop, val = args
                hash[prop] = val
                @node['style'] = hash_to_css(hash)
                return self
            end
        end

        def hide
            (@nodeset || [@node]).each{|n|
                css = n['style'] || ''
                hash = parse_css css
                hash['display'] = 'none'
                n['style'] = hash_to_css(hash)
            }
            self
        end

        def data(*args)
            argl = args.length
            if argl.zero?
                return {} if !@node
                attrs = @node.attributes
                res = {}
                attrs.each{|a,v|
                    res[a] = v if a[/^data-/]
                }
                res
            elsif argl == 1
                arg = args[0]
                if hashlike?(arg)
                    arg.each{|name, val|
                        @node["data-#{name}"] = val
                    } if @node
                    self
                else
                   return nil if !@node
                   @node["data-#{arg}"]
                end
            else
                name, val = args
                if @node
                    @node["data-#{name}"] = val
                end
                self
            end
        end

        def as_template(obj, opts = nil)
            opts ||= {}
            nl = opts[:new_line]
            res = self
            if @node
                if obj.is_a? String
                    @node.content = obj
                elsif hashlike?(obj)
                    obj.each{|attr, v|
                        attr_s = attr.to_s
                        if v.nil? && !@node[attr_s].nil?
                            @node.remove_attribute attr_s
                        elsif attr == :content
                            v = '' if v.nil?
                            @node.content = v.to_s
                        elsif attr == :data && hashlike?(v)
                            v.each{|data_name, data_val|
                                @node["data-#{data_name}"] = data_val 
                            }                            
                        elsif attr == :select && hashlike?(v)
                            v.each{|sel, o|
                                e = self.find sel.to_s
                                e.as_template(o)
                            }
                        else
                            @node[attr_s] = v
                        end
                    }
                elsif obj.is_a? Array
                    last = @node
                    obj.each{|o|
                        _node = @node.clone
                        e = HTML.new(_node)
                        if block_given?
                            yield e, o
                        else
                            e.as_template(o)
                        end
                        last.after("\n") if nl
                        last.after(e.node)
                        last = e.node
                    }
                    @node.remove
                end
            end
            res
        end

        def to_html
            @node.to_html
        end

        def to_xhtml
            @node.to_xhtml
        end

        def to_xml
            @node.to_xml
        end

        def to_s
            super if !@node
            if @node.xml?
                to_xml
            else
                to_html
            end
        end

        def clone
            _clone = super
            _clone.instance_eval{
                @node = @node.clone if @node
                @nodeset = @nodeset.clone if @nodeset
                @document = @document.clone if @document
            }
            _clone
        end

        def HTML::parse(text, opts = nil)
            text ||= ''
            opts ||= {}
            opts = {auto: true}.merge(opts)
            if opts[:auto]
                opts[:is_document] = !text.strip[/^<!doctype /i].nil?
            end
            if opts[:is_document]
                HTML.new(Nokogiri::HTML::Document.parse(text))
            else
                HTML.new(text)
            end
        end

        def HTML::parse_doc(text, opts = {})
            opts[:is_document] = true
            HTML::parse text, opts
        end

        def HTML::load(path, opts = {})
            if @@use_cache
                cached = @@cache[path]
                return cached.clone if cached
            end
            opts[:source] = path
            text = File.read path
            HTML::parse text, opts
        end

        def HTML::load_doc(path)
            HTML::load path, is_document: true, source: path
        end

        def HTML::prefix
            @@prefix
        end

        def HTML::prefix=(prfx)
            @@prefix = prfx
        end

        def HTML::evaluation_instance
            @@evaluation_instance
        end

        def HTML::evaluation_instance=(obj)
            @@evaluation_instance = obj
        end

        def HTML::evaluation_binding
            @@evaluation_binding
        end

        def HTML::evaluation_binding=(b)
            @@evaluation_binding = b
        end

        def HTML::include_path
            @@include_path
        end

        def HTML::include_path=(path)
            @@include_path = path
        end
        
        private

        def raise_err(msg, line = nil)
            args = [HTMLException, msg]
            args << "#{@source}:#{line}" if @source && line
            raise *args
        end

        def add_class_to(_node, classname)
            cls = _node['class'] || ''
            classes = cls.split(/\s+/)
            return if classes.include? classname
            cls = (classes << classname).join(' ')
            _node['class'] = cls
        end

        def remove_class_from(_node, classname)
            cls = _node['class'] || ''
            cls = cls.split(/\s+/).select{|c| c != classname}.join(' ')
            _node['class'] = cls
        end

        def hashlike?(obj) 
            obj.is_a?(Hash) || (!obj.is_a?(Array) && 
                                obj.respond_to?(:[]) && 
                                obj.respond_to?(:each))
        end

        def resolvepath(path)
            return path if path[/^\//]
            if (include_path = @@include_path)
                if !include_path[/^\//]
                    script_path = File.dirname(File.expand_path($0))
                    include_path = File.join(script_path, include_path)
                end
                include_path = File.join(include_path, path)
                path = include_path if File.exists? include_path 
            end
            path
        end

        def parse_css(css)
            o = {}
            css = css.strip.gsub(/^\{/, '').gsub(/\}$/, '')
            decls = css.split(';')
            decls.each{|d|
                prop, val = d.strip.split(':')
                o[prop.strip] = val.strip
            }
            o
        end

        def hash_to_css(hash)
            hash.to_a.map{|d|
                prop, val = d
                "#{prop}: #{val}"
            }.join('; ')
        end

    end

    class HTMLBuilder

        def initialize(parent)
            @parent = parent
        end

        def mode(mode)
            @mode = mode
            self
        end

        def method_missing(m, attrs = {}, &block)
            attrs[:_doc] = @parent
            element = HTML.new m, attrs, &block
            if @mode == :prepend
                @parent.prepend element
            else
                @parent.append element
            end
            element
        end

    end

end
