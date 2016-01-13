module Weby

    class HTMLException < Exception
    end

    class HTML

        attr_accessor :node, :nodeset, :document

        def initialize(obj, opts = {}, &block)
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
                raise HTMLException, ':_doc option is missing' if !@document
                @document = @document.document if @document.is_a?(HTML)
                if !@document.is_a?(Nokogiri::XML::DocumentFragment) && 
                   !@document.is_a?(Nokogiri::XML::Document)
                    raise HTMLException, 
                          ':_doc must be Nokogiri::XML::Document(Fragment)'
                end
                @node = Nokogiri::XML::Element.new obj.to_s, @document
                opts.delete :_doc
                opts.each{|attr, val|
                    next if val.nil?
                    @node[attr] = val
                }
                self.exec(&block) if block_given?
            elsif obj.is_a? String
                @node = Nokogiri::HTML::DocumentFragment.parse obj
                @document = @node
                @is_fragm = true
            end
            @document ||= (@nodeset || @node).document
        end

        def builder
            @builder ||= HTMLBuilder.new(self)
        end

        def exec(mode = :append, &block)
            text = builder.mode(mode).instance_eval(&block)
            @node.add_child text if text.is_a? String
            text
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

        def as_template(obj)
            res = self
            if @node
                if obj.is_a? String
                    @node.content = obj
                elsif obj.is_a? Hash
                    obj.each{|attr, v|
                        attr_s = attr.to_s
                        if v.nil? && !@node[attr_s].nil?
                            @node.remove_attribute attr_s
                        elsif attr == :content
                            v = '' if v.nil?
                            @node.content = v.to_s
                        elsif attr == :data && v.is_a?(Hash)
                            v.each{|data_name, data_val|
                                @node["data-#{data_name}"] = data_val 
                            }                            
                        elsif attr == :select && v.is_a?(Hash)
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

        def HTML::parse(text, opts = {})
            if opts[:is_document]
                HTML.new(Nokogiri::HTML::Document.parse(text))
            else
                HTML.new(text)
            end
        end

        def HTML::parse_doc(text)
            HTML::parse text, is_document: true
        end

        def HTML::load(path, opts = {})
            text = File.read path
            HTML::parse text, opts
        end

        def HTML::load_doc(path)
            HTML::load path, is_document: true
        end
        
        private

        def add_class_to(_node, classname)
            cls = _node['class'] || ''
            cls = (cls.split(/\s+/) << classname).join(' ')
            _node['class'] = cls
        end

        def remove_class_from(_node, classname)
            cls = _node['class'] || ''
            cls = cls.split(/\s+/).select{|c| c != classname}.join(' ')
            _node['class'] = cls
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
