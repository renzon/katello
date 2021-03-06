require File.expand_path("repository_base", File.dirname(__FILE__))

module Katello
  class ProductCreateTest < ActiveSupport::TestCase
    def setup
      super
      User.current = @@admin
      @product = build(:katello_product,
                       :organization => get_organization,
                       :provider => katello_providers(:anonymous)
                      )
      @redhat_product = Product.find(katello_products(:redhat).id)
      @promoted_product = Product.find(katello_products(:fedora).id)
    end

    def teardown
      @product.destroy if @product
    end

    def test_enabled
      products = Product.enabled
      refute_includes products, katello_products(:empty_redhat)
      assert_includes products, @redhat_product
      assert_includes products, katello_products(:empty_product)
    end

    def test_redhat
      assert_includes Product.redhat, @redhat_product
      refute_includes Product.redhat, @promoted_product
    end

    def test_custom
      assert_includes Product.custom, @promoted_product
      refute_includes Product.custom, @redhat_product
    end

    def test_redhat?
      assert @redhat_product.redhat?
      refute @product.redhat?
    end

    def test_user_deletable?
      refute @redhat_product.user_deletable?
      assert @product.user_deletable?
      refute @promoted_product.user_deletable?
    end

    def test_search_redhat
      products = Product.search_for('redhat = true')
      assert_includes products, @redhat_product
      refute_includes products, @promoted_product
    end

    def test_search_custom
      products = Product.search_for('redhat = false')
      assert_includes products, @promoted_product
      refute_includes products, @redhat_product
    end

    def test_search_label
      products = Product.search_for("label = #{@redhat_product.label}")
      assert_includes products, @redhat_product
    end

    def test_search_description
      products = Product.search_for("description = \"#{@redhat_product.description}\"")
      assert_includes products, @redhat_product
    end

    def test_create
      assert @product.save
      refute_empty Product.where(:id => @product.id)
    end

    def test_unique_name_per_organization
      @product.save!
      @product2 = build(:katello_product,
                        :organization => @product.organization,
                        :provider => @product.provider,
                        :name => @product.name,
                        :label => 'Another Label')

      refute @product2.valid?
    end

    def test_unique_label_per_organization
      @product.save!
      @product2 = build(:katello_product,
                        :organization => @product.organization,
                        :provider => @product.provider,
                        :name => 'Another Name',
                        :label => @product.label)

      refute @product2.valid?
    end

    def test_syncable_content
      products_with_syncable_repos = Product.all.select do |prod|
        prod.repositories.any? { |r| r.url.present? }
      end
      products = Katello::Product.syncable_content
      assert_equal products_with_syncable_repos.length, products.length
      products.each { |prod| assert prod.syncable_content? }
    end

    def test_not_used_by_other_org
      refute @redhat_product.used_by_another_org?
    end

    def test_used_by_other_orgs
      other_org = taxonomies(:organization1)
      create(:katello_product,
             :cp_id => @redhat_product.cp_id,
             :organization => other_org,
             :name => @redhat_product.name,
             :label => 'dont_label_me',
             :provider => other_org.redhat_provider)

      assert @redhat_product.used_by_another_org?
    end

    def test_subscribable_with_puppet_repo
      puppet_repo = katello_repositories(:p_forge)
      product = katello_products(:fedora)
      Repository.any_instance.stubs(:exist_for_environment?).returns(true)
      product.repositories = [puppet_repo]

      refute_includes Product.subscribable, product
    end

    def test_subscribable_without_repos
      product = katello_products(:fedora)
      product.repositories = []

      assert_includes Product.subscribable, product
    end

    def test_find_product_content_by_id
      (1..2).each do |x|
        content = FactoryBot.create(:katello_content, cp_content_id: "content-#{x}")
        FactoryBot.create(:katello_product_content, content: content, product: @redhat_product)
      end

      expected = 'content-2'
      found_content = @redhat_product.product_content_by_id(expected)

      assert_equal expected, found_content.content.cp_content_id
    end

    def test_subscribable_puppet_and_yum_repos
      product = katello_products(:fedora)
      Repository.any_instance.stubs(:exist_for_environment?).returns(true)
      product.repositories << katello_repositories(:p_forge)

      assert_includes Product.subscribable, product
    end

    def test_available_content
      product = katello_products(:fedora)
      fedora = katello_repositories(:fedora_17_x86_64)
      puppet = katello_repositories(:p_forge)

      fedora_content = product.product_contents.to_a
      puppet.update_attributes(content_id: 2)

      content = FactoryBot.create(:katello_content, cp_content_id: puppet.content_id)
      FactoryBot.create(:katello_product_content, content: content, product: product)

      Repository.any_instance.stubs(:exist_for_environment?).returns(true)
      product.repositories = [fedora, puppet]

      assert_equal fedora_content, product.available_content
    end
  end
end
