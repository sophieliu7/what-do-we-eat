
class UserProductsController < ApplicationController
  before_action :set_user_product, only: [:edit, :update, :destroy, :toggle_selection]

  def index
    UserProduct.all.each do |uproduct|
      uproduct.selected = false
      uproduct.save
    end

    @user = current_user
    if params[:query].present?
      @user_products = UserProduct.global_search(params[:query])
    else
      @user_products = UserProduct.where(user_id: current_user).order('peremption_date ASC')
    end
  end

  def new
    @user_product = UserProduct.new
    if params[:search]
      @product = Product.first
    end
  end

  def load_form

    params[:products][:product_id]


    if (params[:products][:product_id] =~(/\d+/)).nil?
      name = params[:products][:product_id]
      product = Product.create(name: name)
      @product_name = product.name
    else
      product = Product.find(params[:products][:product_id]).name
      @product_name = product

    end
    # format JS > load_form.js.erb
    respond_to do |format|
      format.js # actually means: if the client ask for js -> return file.js
    end
    # passer un produit @product

  end

  def create
    @category = Category.find(params[:category_id])
    @product = Product.find_by(name: params[:product_name]) || Product.new(name: params[:product_name])
    @product.category = @category
    @product.save

    @user_product = UserProduct.new(user_products_params)
    if @user_product.peremption_date.nil?
      @user_product.peremption_date = Date.today + @category.peremption_duration.days
    end

    @user_product.user = current_user

    @user_product.product = @product
    if @user_product.save
      redirect_to user_products_path
    else
      render :new
    end


  end

  def edit
  end

  def update
    if @user_product.update(user_products_params)
      redirect_to user_products_path
    else
      render :edit
    end
  end

  def destroy
    @user_product.destroy

    # redirect_to user_products_path
  end

  def email
    return nil if email_parser_content.nil?
    @email_content = email_parser_content
    @email_date = email_parser_date
    @email_user = email_parser_user
    @email_from = email_parser_email_from
    # @hash_food_category = hash_email_food_with_category_from_db_or_carrefour
    # @email_content = ['Brandade de morue à la nîmoise Reflets de France', 'clafoutis', 'Thon à la provencale', "Mini saucisson Bâton de Berger nature Justin Bridou"]
    # @email_date = '2018_08_30'
    # @email_user = 'sliu@sarenza.com'
    # @email_from = 'sliu@sarenza.com'

  end


  def create_user_products_from_emails

    #raise

    # pour chaque string du mail parsé on boucle :
    hash_email_food_with_category_from_db_or_carrefour.each do |food, category|
      # check si le Product existe ou pas
      temp_product = Product.find_by_name(food)
      if temp_product.nil?
        # si n'existe pas alors on créé le Product, la catégorie (selon les cas) et le user product associé
          if Category.find_by_name(category).nil?
            Category.create!(name: category, SubCategory: "autre", peremption_duration: 30)
          end
        temp_category = Category.find_by_name(category)
        new_product = Product.create!(name: food, category: temp_category)
        UserProduct.create!(user: current_user, product: new_product, purchase_date: Date.today, peremption_date: Date.today + temp_category.peremption_duration.days)
      else
        temp_category = Category.find_by_name(category)
        # si il existe alors on créé juste le user product avec l'association product
        UserProduct.create!(user: current_user, product: temp_product, purchase_date: Date.today, peremption_date: Date.today + temp_category.peremption_duration.days)
      end
    end
    # on détruit l'email ensuite
    destroy_emails
    redirect_to user_products_path
  end

  def toggle_selection
    if @user_product.selected == false
      @user_product.selected = true
    else
      @user_product.selected = false
    end
    @user_product.save
    respond_to do |format|
      format.html { redirect_to user_products_path }
      format.js
    end
  end

  ################ PRIVATE FUNCTIONS ###########################################

  private

  def user_products_params
    params.require(:user_product).permit(
      :place,
      :purchase_date,
      :peremption_date,
      :product_id
      )
  end

  def set_user_product
    @user_product = current_user.user_products.find(params[:id])
  end

  def render_error
    render json: { errors: @user_product.errors.full_messages },
      status: :unprocessable_entity
  end

# Fonction qui renvoit un ARRAY de string correspondant aux noms des produits de la liste
# de course Carrefour du DERNIER email envoyé par le Current User

  def email_parser_content

    email = InboundEmail.where( user_id: current_user ).last
    return nil if email.nil?

    item_list = email.content["TextBody"].split(/Produits commandés/).last.split(/Montant du panier/).first

    item_list2 = item_list.split(/\r\n/).reject! { |string| string == "" }

    item_list2.map! { |string| string.strip }

    item_list2.reject! { |string|
      string.last(2) =~ /\d\sg/ ||
      string.last(2) =~ /\dg/ ||
      string.last(2) =~ /((c|C)|(l|L))/ ||
      string.last(2) =~ /((m|M)|(l|L))/ ||
      string.last(2) =~ /((d|D)|(l|L))/ ||
      string.last(2) =~ /((k|K)|(g|G))/ ||
      string.last(2) =~ /((m|M)|(g|G))/ ||
      string.last(2) =~ /((d|D)|(g|G))/ ||
      string =~ /.+\d{2,}(\s|)g.+/ ||
      string =~ /.+\sPrix\sunitaire.+/ ||
      string.last(5) =~ /payer/ ||
      string.length < 3 ||
      string.last(1) =~ /€/ }

      require 'csv'
      filepath = 'app/controllers/blacklist_items.csv'
      blacklist = []
      CSV.foreach(filepath) do |row|
        blacklist << row
      end

      blacklist.flatten!

      blacklist.each do |item|
         item_list2.reject! { |string| string.upcase.include? item.upcase }
      end

      return item_list2
  end

# Fonction qui renvoit 1 string correspondant à la date de Forward
# du DERNIER email envoyé par le Current User

  def email_parser_date
    email = InboundEmail.where( user_id: current_user ).last
    return nil if email.nil?
    email.content["Date"]
  end

  def email_parser_user
    email = InboundEmail.where( user_id: current_user ).last
    return nil if email.nil?
    email.user.email
  end

  def email_parser_email_from
    email = InboundEmail.where( user_id: current_user ).last
    return nil if email.nil?
    email.content["From"]
  end

  def destroy_emails
    current_user.inbound_emails.destroy_all
  end
####################### CARREFOUR API CALLS ####################################
require 'uri'
require 'openssl'
require 'net/http'
require 'json'

 # FONCTION appelant Carrefour et retournant la catégorie HypSubCLassDesc

  def post_with_string(word)
    url = URI("https://api.fr.carrefour.io/v1/openapi/items")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    request = Net::HTTP::Post.new(url)
    request["x-ibm-client-id"] = ENV['CARREFOUR_CLIENT_ID']
    request["x-ibm-client-secret"] = ENV['CARREFOUR_CLIENT_SECRET']
    request["content-type"] = 'application/json'
    request["accept"] = 'application/json'
    request.body = "{\"queries\":[{\"query\":\"#{word}\"}]}"

    response = http.request(request)

    if response.read_body.nil?
      return 'RIEN TROUVE'
    elsif response.read_body.start_with?('<?xml')
      return 'API INTERNAL ERROR'
    else
      data = JSON.parse(response.read_body)
      # return data
      return data['list'][0]['category_structures']['hyper']['hypSubClassDesc']
    end
  end


 # ALGO qui réitère sur le nombre de mots de la string juqu'a trouver un résultat via post_with_string

  def find_carrefour_categories(word)

    carrefour_api_response = post_with_string(word)

    if carrefour_api_response == 'API INTERNAL ERROR' || word == ""
      return nil

    else

      number_of_words = word.split.size

      while carrefour_api_response == 'RIEN TROUVE' && number_of_words > 1 && carrefour_api_response != 'API INTERNAL ERROR'
        word = word.split.first(word.split.length - 1).join(' ')
        number_of_words = word.split.count
        carrefour_api_response = post_with_string(word)
      end

      return carrefour_api_response
    end
  end


  def hash_food_category(array_of_food)
    result = Hash.new
    array_of_food.each do |food|

      result[food] = find_carrefour_categories(food)
    end
    return result
  end

  def hash_email_food_with_category_from_db_or_carrefour
    result = Hash.new
    email_parser_content.each do |food|
      # regarde si le produit existe déja en base ou pas
      temp_product = Product.find_by_name(food)
        if temp_product.nil?
        # si existe pas en base alors on appelle l'API de carrefour
          result[food] = find_carrefour_categories(food)
        else
        # si il existe en base alors on prend la categories en base
          result[food] = temp_product.category.name
        end
      end
    return result
  end


end
