class CollectionsController < ApplicationController
  
  before_filter :users_only, :only => [:new, :edit, :create, :update]
  before_filter :load_collection_from_id, :only => [:show, :edit, :update, :destroy]
  before_filter :collection_owners_only, :only => [:edit, :update, :destroy]
  
  cache_sweeper :collection_sweeper
  cache_sweeper :static_sweeper  
  
  def load_collection_from_id
    @collection = Collection.find_by_name(params[:id])
  end

  def index
    if params[:work_id] && (@work = Work.find_by_id(params[:work_id]))
      @collections = @work.approved_collections.by_title.paginate(:page => params[:page])
    elsif params[:collection_id] && (@collection = Collection.find_by_name(params[:collection_id]))
      @collections = @collection.children.by_title.paginate(:page => params[:page])
    elsif params[:user_id] && (@user = User.find_by_login(params[:user_id]))
      @collections = @user.owned_collections.by_title.paginate(:page => params[:page])
    else
      if params[:user_id]
        flash[:error].now = ts("We couldn't find a user by that name, sorry.")
      elsif params[:collection_id]
        flash[:error].now = ts("We couldn't find a collection by that name.")
      elsif params[:work_id]
        flash[:error].now = ts("We couldn't find that work.")
      end
      @sort_and_filter = true
      params[:collection_filters] ||= {}
      params[:sort_column] = "collections.created_at" if !valid_sort_column(params[:sort_column], 'collection')
      params[:sort_direction] = 'DESC' if !valid_sort_direction(params[:sort_direction])
      sort = params[:sort_column] + " " + params[:sort_direction]      
      @collections = Collection.sorted_and_filtered(sort, params[:collection_filters], params[:page])
    end
  end
  
  # display challenges that are currently taking signups
  def list_challenges
    @hide_dashboard = true
    @challenge_collections = Collection.signups_open.limit(25)
  end

  def show
    unless @collection
  	  flash[:error] = t('collection_not_found', :default => "Sorry, we couldn't find the collection you were looking for.")
      redirect_to collections_path and return
    end
    
    if @collection.collection_preference.show_random? || params[:show_random]
      # show a random selection of works/bookmarks
      @works = Work.in_collection(@collection).visible.random_order.limit(ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD)
      visible_bookmarks = @collection.bookmarks.visible(:order => 'RAND()')
    else
      # show recent
      @works = Work.in_collection(@collection).visible.ordered_by_date_desc.limit(ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD)
      visible_bookmarks = @collection.bookmarks.visible(:order => 'bookmarks.created_at DESC')
    end
    # Having the number of items as a limit was finding the limited number of items, then visible ones within them
    @bookmarks = visible_bookmarks[0...ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD]

  end

  def new
    @hide_dashboard = true
    @collection = Collection.new
    if params[:collection_id] && (@collection_parent = Collection.find_by_name(params[:collection_id]))
      @collection.parent_name = @collection_parent.name
    end
  end

  def edit
  end

  def create
    @hide_dashboard = true
    @collection = Collection.new(params[:collection])

    # add the owner
    owner_attributes = []
    (params[:owner_pseuds] || [current_user.default_pseud]).each do |pseud_id|
      pseud = Pseud.find(pseud_id)
      owner_attributes << {:pseud => pseud, :participant_role => CollectionParticipant::OWNER} if pseud
    end
    @collection.collection_participants.build(owner_attributes)
    
    if @collection.save
      flash[:notice] = 'Collection was successfully created.'
      unless params[:challenge_type].blank?
        # This is a challenge collection
        redirect_to eval("new_collection_#{params[:challenge_type].demodulize.tableize.singularize}_path(@collection)") and return
      else
        redirect_to(@collection)
      end
    else
      render :action => "new"
    end
  end

  def update
    if @collection.update_attributes(params[:collection])
      flash[:notice] = 'Collection was successfully updated.'
      if params[:challenge_type].blank?
        if @collection.challenge
          # trying to destroy an existing challenge
          flash[:error] = "Note: if you want to delete an existing challenge, please do so on the challenge page."
        end
      else
        if @collection.challenge
          if @collection.challenge.class.name != params[:challenge_type]
            flash[:error] = "Note: if you want to change the type of challenge, first please delete the existing challenge on the challenge page."
          else
            # editing existing challenge
            redirect_to eval("edit_collection_#{params[:challenge_type].demodulize.tableize.singularize}_path(@collection)") and return
          end
        else
          # adding a new challenge
          redirect_to eval("new_collection_#{params[:challenge_type].demodulize.tableize.singularize}_path(@collection)") and return
        end
      end
      redirect_to(@collection)
    else
      render :action => "edit"
    end
  end

  def destroy
    @hide_dashboard = true
    @collection = Collection.find_by_name(params[:id])
    @collection.destroy

    redirect_to(collections_url) 
  end
  
end
