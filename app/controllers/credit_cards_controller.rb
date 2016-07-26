class CreditCardsController < ApplicationController
  before_action :set_webpay, only: [:create, :destroy, :retry]
  before_action :check_plan_user, only: [:create]
  protect_from_forgery except: :create

  def index
    redirect_to root_path
  end

  def new
    # params[:format]でプランのidが入ってい
    @plan = Plan.find(params[:format])
    @credit_card = current_user.credit_cards.build
  end

  def create
    if current_user.payments.last.try(:amount) == 1000
      @webpay.recursion.delete(id: current_user.payments.last.webpay_recursion_id)
      User.delete_dependent(current_user)
    end
    # 顧客登録
    begin
      @user = @webpay.customer.create(card: params['webpay-token'])
      recursion = CreditCard.webpay_customer_create(credit_params['amount'], @user, @webpay)
      CreditCard.create_credit_card(current_user, @user)
      # クレジットカードが登録された後に中間テーブルのプランユーザテーブルが作成される
      UserPlan.create_user_plan(params[:credit_card][:amount], current_user)
      Subscription.create_subscription(session[:project_id], current_user)
      # クレジットカードが登録された後に支払い方法が登録される
      Payment.create_payment(recursion, current_user, params[:credit_card][:amount])
      200
      redirect_to root_path
      # 顧客idも保存しておかないといけないかも(削除時に必要かもしれない)
    rescue WebPay::ErrorResponse::InvalidRequestError => e
      flash[:error] = e.message
      redirect_to root_path
    end
  end

  def destroy
    @webpay.recursion.delete(id: current_user.payments.first.webpay_recursion_id)
    User.delete_dependent(current_user)
    puts 200
    redirect_to root_path
  end

  def retry
    begin
      Payment.card_retry(current_user, @webpay)
      redirect_to myprojects_path
    rescue => e
      logger.error e
      flash.notice = "こちらのカードが現在使えません"
      redirect_to myprojects_path
    end
  end

  private

  def check_plan_user
    return 400 if env['HTTP_X_WEBPAY_ORIGIN_CREDENTIAL'] != Settings.webpay.credential

    if params[:type] == 'recursion.failed'
      credit_card = CreditCard.find_by(webpay_customer_id: params[:data][:object][:customer])
      if params[:data][:object][:status] == "suspended"
        Subscription.where(user_id: credit_card.user_id).update_all(deleted_at: Time.now)
        Payment.create(user_id: credit_card.user_id, status: 1, amount: params[:data][:object][:amount], webpay_recursion_id: params[:data][:object][:id])
      end

      if params[:data][:object][:status] == "closed"
        Subscription.where(user_id: credit_card.user_id).update_all(deleted_at: Time.now)
        Payment.create(user_id: credit_card.user_id, status: 2, amount: params[:data][:object][:amount], webpay_recursion_id: params[:data][:object][:id])
      end
    end

    if params[:type] == 'recursion.succeeded'
      credit_card = CreditCard.find_by(webpay_customer_id: params[:data][:object][:customer])
      Payment.create(user_id: credit_card.user_id, status: 0, amount: params[:data][:object][:amount], webpay_recursion_id: params[:data][:object][:id])
    end
    puts 200
    redirect_to root_path
  end

  def credit_params
    params.require(:credit_card).permit(:name, :year, :date, :cc_type, :token, :card_number, :amount)
  end

  def set_webpay
    @webpay = WebPay.new(Settings.webpay.access_key)
  end
end
