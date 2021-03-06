Given /^I have no tags$/ do
  Tag.delete_all
  silence_warnings {load "#{Rails.root}/app/models/fandom.rb"}
end

Given /^basic tags$/ do
  Warning.find_or_create_by_name_and_canonical("No Archive Warnings Apply", true)
  Warning.find_or_create_by_name_and_canonical("Choose Not To Use Archive Warnings", true)
  Rating.find_or_create_by_name_and_canonical("Not Rated", true)
  Rating.find_or_create_by_name_and_canonical("Explicit", true)
  Fandom.find_or_create_by_name_and_canonical("No Fandom", true)
end

When /^I edit the tag "([^\"]*)"$/ do |tag|
  tag = Tag.find_by_name!(tag)
  visit tag_url(tag)
  within(".header") do
    click_link("Edit")
  end
end

When /^I view the tag "([^\"]*)"$/ do |tag|
  tag = Tag.find_by_name!(tag)
  visit tag_url(tag)
end

When /^I create the fandom "([^\"]*)" with id (\d+)$/ do |name, id|
 tag = Fandom.new(:name => name)
 tag.id = id.to_i
 tag.canonical = true
 tag.save
end

Given /^I have a canonical "([^\"]*)" fandom tag named "([^\"]*)"$/ do |media, fandom|
  fandom = Fandom.find_or_create_by_name_and_canonical(fandom, true)
  media = Media.find_or_create_by_name_and_canonical(media, true)
  fandom.add_association media
end

Given /^I add the fandom "([^\"]*)" to the character "([^\"]*)"$/ do |fandom, character|
  char = Character.find_or_create_by_name(character)
  fand = Fandom.find_or_create_by_name(fandom)
  char.add_association(fand)
end

Given /^the tag wrangler "([^\"]*)" with password "([^\"]*)" is wrangler of "([^\"]*)"$/ do |user, password, fandomname|
  tw = User.find_by_login(user)
  if tw.blank?
    tw = Factory.create(:user, {:login => user, :password => password})
    tw.activate
  else
    tw.password = password
    tw.password_confirmation = password
    tw.save
  end
  tw.tag_wrangler = '1'
  visit login_path
  fill_in "User name", :with => user
  fill_in "Password", :with => password
  check "Remember me"
  click_button "Log in"
  assert UserSession.find
  fandom = Fandom.find_or_create_by_name_and_canonical(fandomname, true)
  visit tag_wranglers_url
  fill_in "tag_fandom_string", :with => fandomname
  click_button "Assign"
end