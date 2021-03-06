require_relative '../spec_helper'

# Unit tests for class {Archive::BagitBag}
describe 'Archive::BagitBag' do

  before(:all) do
    @tmpdir = Pathname(Dir.mktmpdir("bagit"))
  end

  after(:all) do
    @tmpdir.rmtree if @tmpdir.exist?
  end

  describe '=== CLASS METHODS ===' do

    # Unit test for method: {Archive::BagitBag.create_bag}
    # Which returns: [Archive::BagitBag] Initialize a new empty bag
    # For input parameters: (None)
    # * pathname [Pathname, String] = The location of the bag home directory
    specify 'Archive::BagitBag#create_bag' do
      bag_dir = @tmpdir.join('create_me')
      bag = Archive::BagitBag.create_bag(bag_dir)
      expect(bag.payload_pathname).to eq(bag_dir.join('data'))
      expect(bag.payload_pathname.exist?).to eq(true)
      expect(bag.bag_pathname.join('bagit.txt').exist?).to eq(true)
      bag_dir.rmtree
    end

   # Unit test for method: {Archive::BagitBag.open_bag}
    # Which returns: [Archive::BagitBag] Locate and verify existence of an existing bag
    # For input parameters: (None)
    # * pathname [Pathname, String] = The location of the bag home directory
    specify 'Archive::BagitBag#open_bag' do
      bag_dir = @tmpdir.join('open_me')
      Archive::BagitBag.create_bag(bag_dir)
      bag = Archive::BagitBag.open_bag(bag_dir)
      expect(bag.payload_pathname).to eq(bag_dir.join('data'))
      expect(bag.payload_pathname.exist?).to eq(true)
      expect(bag.bag_pathname.join('bagit.txt').exist?).to eq(true)
      bag_dir.rmtree

      expect{Archive::BagitBag.open_bag("/dummy/path")}.to raise_exception(RuntimeError, /No bag found/)
    end

  end

  describe '=== INSTANCE METHODS (creating bag) ===' do

    before(:each) do
      @bag_pathname = @tmpdir.join('mybag')
      @bag_pathname.rmtree if @bag_pathname.exist?
      @bagit_bag = Archive::BagitBag.create_bag(@bag_pathname)
      @bagit_bag.bag_checksum_types = [:sha1, :sha256]
    end

    after(:each) do
      @bag_pathname.rmtree if @bag_pathname.exist?
    end

    # Unit test for method: {Archive::BagitBag#bag_pathname}
    # Which returns: [Pathname] The location of the bag home directory
    # For input parameters: (None)
    specify 'Archive::BagitBag#bag_pathname' do
      expect(@bagit_bag.bag_pathname).to eq(@bag_pathname)
    end

    # Unit test for method: {Archive::BagitBag#bag_pathname=}
    # Which returns: [Void] Set the location of the bag home directory
    # For input parameters:
    # * pathname [Pathname, String] = The location of the bag home directory
    specify 'Archive::BagitBag#bag_pathname=' do
      new_pathname = Pathname.new('/new/path')
      @bagit_bag.bag_pathname = new_pathname
      expect(@bagit_bag.bag_pathname).to eq(new_pathname)
    end

    # Unit test for method: {Archive::BagitBag#payload_pathname}
    # Which returns: [Pathname] The location of the bag data directory
    # For input parameters: (None)
    specify 'Archive::BagitBag#payload_pathname' do
      expect(@bagit_bag.payload_pathname).to eq(@bag_pathname.join('data'))
    end

    # Unit test for method: {Archive::BagitBag#write_bagit_txt}
    # Which returns: [Pathname] Generate the bagit.txt tag file
    # For input parameters: (None)
    specify 'Archive::BagitBag#write_bagit_txt' do
      @bagit_bag.write_bagit_txt
      props = @bagit_bag.read_bagit_txt
      expect(props['BagIt-Version']).to eq('0.97')
    end

    # Unit test for method: {Archive::BagitBag#bag_checksum_types}
    # Which returns: [Array<Symbol>] The list of checksum types to be used when generating fixity data
    # For input parameters: (None)
    specify 'Archive::BagitBag#bag_checksum_types' do
      expect(@bagit_bag.bag_checksum_types).to eq(Archive::Fixity.default_checksum_types)
    end

    # Unit test for method: {Archive::BagitBag#bag_checksum_types=}
    # Which returns: [Void] Set the list of checksum types to be used when generating fixity data
    # For input parameters:
    # * types [Object] = The list of checksum types to be used when generating fixity data
    specify 'Archive::BagitBag#bag_checksum_types=' do
      types = [:md5,:sha1]
      @bagit_bag.bag_checksum_types = types
      expect(@bagit_bag.bag_checksum_types).to eq(types)
    end

        # Unit test for method: {Archive::BagitBag#write_manifest_checksums}
    # Which returns: [Hash<Symbol,Pathname] Update each of the manifests with data from the file_fixity_hash] Hash<Symbol,Pathname] Update each of the manifests with data from the file_fixity_hash
    # For input parameters:
    # * manifest_type [String] = The type of manifest file ('manifest' or 'tagmanifest') to be updated
    # * file_fixity_hash [Hash<String,FileFixity>] = A hash containing file ids and fixity data
    # * open_mode [String] = The file open mode (default is 'a')
    specify 'Archive::BagitBag#write_manifest_checksums' do
      manifest_type = 'manifest'
      source_basepath = @fixtures.join('moab-objects/jq937jp0017/v0003/data/content')
      file_fixity_hash = Archive::Fixity.generate_checksums(source_basepath, source_basepath.find,@bagit_bag.bag_checksum_types)
      open_mode = 'w'
      @bagit_bag.write_manifest_checksums(manifest_type, @bagit_bag.add_data_prefix(file_fixity_hash), open_mode)
      manifest_fixity_hash = @bagit_bag.read_manifest_files(manifest_type)
      checksum_hash =  Archive::Fixity.file_checksum_hash(manifest_fixity_hash)
      #ap checksum_hash
      expect(checksum_hash).to eq({
          "data/page-2.jpg" => {
                :sha1 => "43ced73681687bc8e6f483618f0dcff7665e0ba7",
              :sha256 => "42c0cd1fe06615d8fdb8c2e3400d6fe38461310b4ecc252e1774e0c9e3981afa"
          }
      })
    end

    # Unit test for method: {Archive::BagitBag#add_payload_dir}
    # Which returns: [Pathname] Generate file_fixity_hash and send it to #add_payload_files
    # For input parameters:
    # * link_mode [Symbol] = Specifies whether to :copy, :link, or :symlink the files to the payload directory
    # * source_dir [Pathname] = The source location of the directory whose contents are to be ingested
    specify 'Archive::BagitBag#add_payload_dir' do
      link_mode = :copy
      source_dir = @fixtures.join('source-dir')
      @bagit_bag.add_dir_to_payload(link_mode, source_dir)
      expect(@bagit_bag.payload_pathname.children.size).to eq(4)
      manifest_type = 'manifest'
      fixity_hash = @bagit_bag.read_manifest_files(manifest_type)
      checksum_hash =  Archive::Fixity.file_checksum_hash(fixity_hash)
      #ap checksum_hash
      expect(checksum_hash).to eq({
          "data/page-1.jpg" => {
                :sha1 => "0616a0bd7927328c364b2ea0b4a79c507ce915ed",
              :sha256 => "b78cc53b7b8d9ed86d5e3bab3b699c7ed0db958d4a111e56b6936c8397137de0"
          },
          "data/page-2.jpg" => {
                :sha1 => "43ced73681687bc8e6f483618f0dcff7665e0ba7",
              :sha256 => "42c0cd1fe06615d8fdb8c2e3400d6fe38461310b4ecc252e1774e0c9e3981afa"
          },
          "data/page-3.jpg" => {
                :sha1 => "d0857baa307a2e9efff42467b5abd4e1cf40fcd5",
              :sha256 => "235de16df4804858aefb7690baf593fb572d64bb6875ec522a4eea1f4189b5f0"
          },
          "data/page-4.jpg" => {
                :sha1 => "c0ccac433cf02a6cee89c14f9ba6072a184447a2",
              :sha256 => "7bd120459eff0ecd21df94271e5c14771bfca5137d1dd74117b6a37123dfe271"
          }
      })
    end

    # Unit test for method: {Archive::BagitBag#add_payload_files}
    # Which returns: [Pathname] Copy or link the files specified in the file_fixity_hash to the payload directory, then update the payload manifest files
    # For input parameters:
    # * link_mode [Symbol] = Specifies whether to :copy, :link, or :symlink the files to the payload directory
    # * source_basepath [Pathname] = The source location of the directory whose contents are to be ingested
    # * file_fixity_hash [Hash<String,FileFixity>] = The list of files (with fixity data) to be added to the payload
    specify 'Archive::BagitBag#add_payload_files' do
      link_mode = :copy
      source_basepath = @fixtures.join('moab-objects/jq937jp0017/v0002/data')
      file_fixity_hash = Archive::Fixity.generate_checksums(source_basepath, source_basepath.find,@bagit_bag.bag_checksum_types)
      @bagit_bag.add_files_to_payload(link_mode, source_basepath, file_fixity_hash)
      expect(@bagit_bag.payload_pathname.find.select{|f| f.file?}.size).to eq(4)
      manifest_type = 'manifest'
      manifest_fixity_hash = @bagit_bag.read_manifest_files(manifest_type)
      checksum_hash =  Archive::Fixity.file_checksum_hash(manifest_fixity_hash)
      #ap checksum_hash
      expect(checksum_hash).to eq({
                       "data/content/page-1.jpg" => {
                :sha1 => "0616a0bd7927328c364b2ea0b4a79c507ce915ed",
              :sha256 => "b78cc53b7b8d9ed86d5e3bab3b699c7ed0db958d4a111e56b6936c8397137de0"
          },
             "data/metadata/contentMetadata.xml" => {
                :sha1 => "c3961c0f619a81eaf8779a122219b1f860dbc2f9",
              :sha256 => "02b3bb1d059a705cb693bb2fe2550a8090b47cd3c32e823891b2071156485b73"
          },
          "data/metadata/provenanceMetadata.xml" => {
                :sha1 => "565473bbc865b1c6f88efc99b6b5b73fd5cadbc8",
              :sha256 => "ee62fdef9736ff12e394c3510f3d0a6ccd18bd5b1fb7e42fe46800d5934c9001"
          },
             "data/metadata/versionMetadata.xml" => {
                :sha1 => "65ea161b5bb5578ab4a06c4cd77fe3376f5adfa6",
              :sha256 => "291208b41c557a5fb15cc836ab7235dadbd0881096385cc830bb446b00d2eb6b"
          }
      })
    end

    # Unit test for method: {Archive::BagitBag#copy_file}
    # Which returns: [Pathname] link or copy the specified file from source location to the target location
    # For input parameters:
    # * link_mode [Symbol] = Specifies whether to :copy, :link, or :symlink the files to the payload directory
    # * source_pathname [Pathname] = The source location of the file to be ingested
    # * target_pathname [Pathname] = The location of the directory in which to place the file
    specify 'Archive::BagitBag#copy_file' do
      link_mode = :copy
      source_pathname = @fixtures.join('moab-objects/jq937jp0017/v0003/data/content/page-2.jpg')
      expect(source_pathname.exist?).to eq(true)
      target_pathname = @bagit_bag.payload_pathname.join('page-2.jpg')
      expect(target_pathname.exist?).to eq(false)
      @bagit_bag.copy_file(link_mode, source_pathname, target_pathname)
      expect(target_pathname.exist?).to eq(true)
      expect(source_pathname.size).to eq(target_pathname.size)
    end

    # Unit test for method: {Archive::BagitBag#add_payload_tarfile}
    # Which returns: [Archive::Tarfile] Create a tar archive of a directory into the payload directory, generating checksums in parallel processes and recording those checksums in the payload manifests
    # For input parameters:
    # * source_fullpath [Pathname, String] = The location of the directory whose content will be tarred
    # * source_basepath [Pathname, String] = The location of the directory to change to before doing the tar create
    specify 'Archive::BagitBag#add_payload_tarfile' do
      tarfile_id = 'jq937jp0017-v0002'
      source_fullpath = @fixtures.join('moab-objects/jq937jp0017/v0002')
      source_basepath = @fixtures.join('moab-objects')
      tarfile = @bagit_bag.add_payload_tarfile(tarfile_id, source_fullpath, source_basepath)
      expect(tarfile.tarfile_fullpath.basename.to_s).to eq(tarfile_id)
      expect(tarfile.tarfile_fullpath.exist?).to eq(true)
      manifest_type = 'manifest'
      manifest_fixity_hash = @bagit_bag.read_manifest_files(manifest_type)
      checksum_hash =  Archive::Fixity.file_checksum_hash(manifest_fixity_hash)
      #ap checksum_hash
      expect(checksum_hash.keys.first).to eq("data/#{tarfile_id}")
      expect(checksum_hash.values.first.keys).to eq(@bagit_bag.bag_checksum_types)
    end

    # Unit test for method: {Archive::BagitBag#write_bag_info_txt}
    # Which returns: [Pathname] Generate the bag-info.txt tag file to record the payload size
    # For input parameters: (None)
    specify 'Archive::BagitBag#write_bag_info_txt' do
      link_mode = :copy
      source_dir = @fixtures.join('source-dir')
      @bagit_bag.add_dir_to_payload(link_mode, source_dir)
      payload_size = @bagit_bag.bag_payload_size
      expect(payload_size).to eq({:bytes=>131029, :files=>4})
      expect(@bagit_bag.bag_size_human(payload_size[:bytes])).to eq("127.96 KB")
      @bagit_bag.write_bag_info_txt
      properties=@bagit_bag.read_bag_info_txt
      #ap properties
      expect(properties).to eq({
          "External-Identifier" => "mybag",
                 "Payload-Oxum" => "131029.4",
                     "Bag-Size" => "127.96 KB"
      })
      expect(@bagit_bag.info_payload_size).to eq(payload_size)
    end

    # Unit test for method: {Archive::BagitBag#bag_size_human}
    # Which returns: [String] Human-readable rendition of the total payload size
    # For input parameters:
    # * bytes [Integer] = The total number of bytes in the payload
    specify 'Archive::BagitBag#bag_size_human' do
      expect(@bagit_bag.bag_size_human(256)).to eq('256 B')
      expect(@bagit_bag.bag_size_human(1024)).to eq('1.00 KB')
      expect(@bagit_bag.bag_size_human(2222)).to eq('2.17 KB')
      expect(@bagit_bag.bag_size_human(1024*1024)).to eq('1.00 MB')
      expect(@bagit_bag.bag_size_human(1024*1024*1024)).to eq('1.00 GB')
      expect(@bagit_bag.bag_size_human(1024*1024*1024*1024)).to eq('1.00 TB')
      expect(@bagit_bag.bag_size_human(1024*1024*1024*1024*1024)).to eq('1024.00 TB')
    end

  end

  describe '=== INSTANCE METHODS (existing bag) ===' do


    before(:all) do
      @bag_pathname = @tmpdir.join('existing_bag')
      @bag_pathname.rmtree if @bag_pathname.exist?
      @bagit_bag = Archive::BagitBag.create_bag(@bag_pathname)
      link_mode = :copy
      source_dir = @fixtures.join('source-dir')
      @bagit_bag.add_dir_to_payload(link_mode, source_dir)
      @bagit_bag.write_bag_info_txt
      @bagit_bag.write_manifest_checksums('tagmanifest', @bagit_bag.generate_tagfile_checksums)
    end

    after(:all) do
      @bag_pathname.rmtree if @bag_pathname.exist?
    end


    # Unit test for method: {Archive::BagitBag#verify_payload_size}
    # Which returns: [Boolean] Compare the actual measured payload size against the value recorded in bag-info.txt
    # For input parameters: (None)
    specify 'Archive::BagitBag#verify_payload_size' do
      expect(@bagit_bag.verify_payload_size).to eq(true)
    end

    # Unit test for method: {Archive::BagitBag#generate_tagfile_checksums}
    # Which returns: [Hash<String,Archive::FileFixity>] create hash containing ids and checksums for all files in the bag's root directory
    # For input parameters: (None)
    specify 'Archive::BagitBag#generate_tagfile_checksums' do
      tagfile_fixity_hash = @bagit_bag.generate_tagfile_checksums
      checksum_hash = Archive::Fixity.file_checksum_hash(tagfile_fixity_hash)
      #ap checksum_hash
      expect(checksum_hash).to eq({
                    "bag-info.txt" => {
                :sha1 => "296fcefcad7327be9e644ac822aed9d7ff9781a1",
              :sha256 => "7f2daef0f9bfa07d91b0d361bdb70bfdb369a89f307bec907fa1edfd2ee3f05e"
          },
                       "bagit.txt" => {
                :sha1 => "37675e3c2ecc0ea050f382c4f05da5e802f77d4d",
              :sha256 => "4227e88364c1f99ceb6aa9da763f5a9db345cb56d4a97ea56e5fb4e34e5123fd"
          },
               "manifest-sha1.txt" => {
                :sha1 => "e5d99e3800fbfa2629e163b8c1ac2de87a074350",
              :sha256 => "b1f5a94ab6fb199aac8e1e1970a96e508bc26cea4598fa683cc99f881445fe41"
          },
             "manifest-sha256.txt" => {
                :sha1 => "8d9fb84cc55035e4d371c4408da894f3f436f7e2",
              :sha256 => "5917df61589ad4b42cec0f0af36077a6f4c573ab6e85a69f6f4243b3b7f60be9"
          }
      })
    end

    # Unit test for method: {Archive::BagitBag#generate_payload_checksums}
    # Which returns: [Hash<String,Archive::FileFixity>] create hash containing ids and checksums for all files in the bag's payload
    # For input parameters: (None)
    specify 'Archive::BagitBag#generate_payload_checksums' do
      payload_fixity_hash = @bagit_bag.generate_payload_checksums
      checksum_hash = Archive::Fixity.file_checksum_hash(payload_fixity_hash)
      #ap checksum_hash
      expect(checksum_hash).to eq({
          "data/page-1.jpg" => {
                :sha1 => "0616a0bd7927328c364b2ea0b4a79c507ce915ed",
              :sha256 => "b78cc53b7b8d9ed86d5e3bab3b699c7ed0db958d4a111e56b6936c8397137de0"
          },
          "data/page-2.jpg" => {
                :sha1 => "43ced73681687bc8e6f483618f0dcff7665e0ba7",
              :sha256 => "42c0cd1fe06615d8fdb8c2e3400d6fe38461310b4ecc252e1774e0c9e3981afa"
          },
          "data/page-3.jpg" => {
                :sha1 => "d0857baa307a2e9efff42467b5abd4e1cf40fcd5",
              :sha256 => "235de16df4804858aefb7690baf593fb572d64bb6875ec522a4eea1f4189b5f0"
          },
          "data/page-4.jpg" => {
                :sha1 => "c0ccac433cf02a6cee89c14f9ba6072a184447a2",
              :sha256 => "7bd120459eff0ecd21df94271e5c14771bfca5137d1dd74117b6a37123dfe271"
          }
      })
    end

    # Unit test for method: {Archive::BagitBag#read_manifest_files}
    # Which returns: [Hash<String,Archive::FileFixity>] A hash containing file ids and fixity data derived from the manifest files
    # For input parameters:
    # * manifest_type [String] = The type of manifest file ('manifest' or 'tagmanifest') to be read
    specify 'Archive::BagitBag#read_manifest_files' do
      manifest_type = 'manifest'
      manifest_fixity_hash = @bagit_bag.read_manifest_files(manifest_type)
      checksum_hash =  Archive::Fixity.file_checksum_hash(manifest_fixity_hash)
      #ap checksum_hash
      expect(checksum_hash).to eq({
          "data/page-1.jpg" => {
                :sha1 => "0616a0bd7927328c364b2ea0b4a79c507ce915ed",
              :sha256 => "b78cc53b7b8d9ed86d5e3bab3b699c7ed0db958d4a111e56b6936c8397137de0"
          },
          "data/page-2.jpg" => {
                :sha1 => "43ced73681687bc8e6f483618f0dcff7665e0ba7",
              :sha256 => "42c0cd1fe06615d8fdb8c2e3400d6fe38461310b4ecc252e1774e0c9e3981afa"
          },
          "data/page-3.jpg" => {
                :sha1 => "d0857baa307a2e9efff42467b5abd4e1cf40fcd5",
              :sha256 => "235de16df4804858aefb7690baf593fb572d64bb6875ec522a4eea1f4189b5f0"
          },
          "data/page-4.jpg" => {
                :sha1 => "c0ccac433cf02a6cee89c14f9ba6072a184447a2",
              :sha256 => "7bd120459eff0ecd21df94271e5c14771bfca5137d1dd74117b6a37123dfe271"
          }
      })
    end

    # Unit test for method: {Archive::BagitBag#manifest_diff}
    # Which returns: [Hash] A report of the differences between the fixity data from the manifest files against the values measured by digesting the files
    # For input parameters:
    # * manifest_fixity_hash [Hash<String,Archive::FileFixity>] = A hash containing file ids and fixity data derived from the manifest files
    # * bag_fixity_hash [Hash<String,Archive::FileFixity>] = A hash containing file ids and fixity data derived from the actual files
    specify 'Archive::BagitBag#manifest_diff' do
      manifest_fixity_hash =  @bagit_bag.read_manifest_files('manifest')
      bag_fixity_hash = @bagit_bag.generate_payload_checksums
      expect(@bagit_bag.manifest_diff(manifest_fixity_hash, bag_fixity_hash)).to eq({})

      bag_fixity_hash["data/page-1.jpg"].checksums[:sha1] = "c0ccac433cf02a6cee89c14f9ba6072a184447a2"
      diff = @bagit_bag.manifest_diff(manifest_fixity_hash, bag_fixity_hash)
      #ap diff
      expect(diff).to eq({
          "data/page-1.jpg" => {
              :sha1 => {
                  "manifest" => "0616a0bd7927328c364b2ea0b4a79c507ce915ed",
                       "bag" => "c0ccac433cf02a6cee89c14f9ba6072a184447a2"
              }
          }
      })
    end


    # Unit test for method: {Archive::BagitBag#verify_manifests}
    # Which returns: [Boolean] Compare fixity data from the manifest files against the values measured by digesting the files, returning true if equal or false if not equal
    # For input parameters:
    # * manifest_type [String] = The type of manifest file ('manifest' or 'tagmanifest') to be read
    # * manifest_fixity_hash [Hash<String,Archive::FileFixity>] = A hash containing file ids and fixity data derived from the manifest files
    # * bag_fixity_hash [Hash<String,Archive::FileFixity>] = A hash containing file ids and fixity data derived from the actual files
    specify 'Archive::BagitBag#verify_manifests' do
      manifest_fixity_hash =  @bagit_bag.read_manifest_files('manifest')
      bag_fixity_hash = @bagit_bag.generate_payload_checksums
      expect(@bagit_bag.verify_manifests('manifest',manifest_fixity_hash, bag_fixity_hash)).to eq(true)

      bag_fixity_hash["data/page-1.jpg"].checksums[:sha1] = "c0ccac433cf02a6cee89c14f9ba6072a184447a2"
      expect{@bagit_bag.verify_manifests('manifest',manifest_fixity_hash, bag_fixity_hash)
        }.to  raise_exception(/Failed manifest verification/)
    end

    # Unit test for method: {Archive::BagitBag#verify_tagfile_manifests}
    # Which returns: [Boolean] Compare fixity data from the tag manifest files against the values measured by digesting the files
    # For input parameters: (None)
    specify 'Archive::BagitBag#verify_tagfile_manifests' do
      expect(@bagit_bag.verify_tagfile_manifests).to eq(true)
    end

    # Unit test for method: {Archive::BagitBag#verify_payload_manifests}
    # Which returns: [Boolean] Compare fixity data from the payload manifest files against the values measured by digesting the files
    # For input parameters: (None)
    specify 'Archive::BagitBag#verify_payload_manifests' do
      expect(@bagit_bag.verify_payload_manifests).to eq(true)
    end


    # Unit test for method: {Archive::BagitBag#verify_bag}
    # Which returns: [Boolean] Validate the bag containing the digital object
    # For input parameters: (None)
    specify 'Archive::BagitBag#verify_bag' do
      expect(@bagit_bag.verify_bag).to eq(true)
    end

    # Unit test for method: {Archive::BagitBag#verify_bag_structure}
    # Which returns: [Boolean] Test the existence of expected files, return true if files exist, raise exception if not
    # For input parameters: (None)
    specify 'Archive::BagitBag#verify_bag_structure' do
      expect(@bagit_bag.verify_bag_structure).to eq(true)
    end

    # Unit test for method: {Archive::BagitBag#verify_pathname}
    # Which returns: [Boolean] Test the existence of the specified path.  Return true if file exists, raise exception if not
    # For input parameters:
    # * pathname [Pathname] = The file whose existence should be verified
    specify 'Archive::BagitBag#verify_pathname' do
      expect(@bagit_bag.verify_pathname(@fixtures)).to eq(true)
    end

  end

end
