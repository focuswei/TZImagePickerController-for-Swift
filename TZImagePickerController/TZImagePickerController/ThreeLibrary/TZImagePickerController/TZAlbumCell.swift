//
//  TZAlbumCell.swift
//  TZImagePickerController
//
//  Created by FocusWei on 2019/11/15.
//  Copyright © 2019 FocusWei. All rights reserved.
//

import UIKit

class TZAlbumCell: UITableViewCell {
    
    var selectedCountButton: UIButton
    var albumCellDidSetModelClosure: ((_ albumCell: TZAlbumCell, _ posterImageView: UIImageView, _ titleLabel: UILabel) -> Void)?
    var albumCellDidLayoutSubviewsClosure: ((_ albumCell: TZAlbumCell, _ posterImageView: UIImageView, _ titleLabel: UILabel) -> Void)?
    
    private var titleLabel: UILabel
    private var posterImageView: UIImageView
    let titleFont = UIFont.systemFont(ofSize: 16)
    let titleTextColor = UIColor.black
    var model: TZAlbumModel? {
        didSet {
            guard let myModel = self.model else { return }
            let attributes_name: [NSAttributedString.Key:Any] = [NSAttributedString.Key.font:titleFont,NSAttributedString.Key.foregroundColor:titleTextColor]
            let nameString = NSMutableAttributedString.init(string: "\(myModel.name)\n", attributes: attributes_name)
            
            let attributes_count: [NSAttributedString.Key:Any] = [NSAttributedString.Key.font:UIFont.systemFont(ofSize: 16),NSAttributedString.Key.foregroundColor:UIColor.black]
            let countString = NSMutableAttributedString.init(string: String(format: "%zd", myModel.count), attributes: attributes_count)
            
            nameString.append(countString)
            self.titleLabel.attributedText = nameString
            TZImageManager.manager.getPostImage(with: myModel) { (postImage) in
                self.posterImageView.image = postImage
            }
            
            if myModel.selectedCount > 0 {
                self.selectedCountButton.isHidden = false
                self.selectedCountButton.setTitle(String(format: "%zd", myModel.selectedCount), for: .normal)
            } else {
                self.selectedCountButton.isHidden = true
            }
            
            self.albumCellDidSetModelClosure?(self, posterImageView, titleLabel)
        }
    }
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        titleLabel = UILabel.init()
        selectedCountButton = UIButton.init()
        posterImageView = UIImageView.init()
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.accessoryType = .disclosureIndicator
        
        selectedCountButton.layer.cornerRadius = 12
        selectedCountButton.clipsToBounds = true
        selectedCountButton.backgroundColor = UIColor.red
        selectedCountButton.setTitleColor(UIColor.white, for: .normal)
        selectedCountButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        self.contentView.addSubview(selectedCountButton)
        
        
        titleLabel.font = titleFont
        titleLabel.textColor = titleTextColor
        titleLabel.numberOfLines = 2
        titleLabel.textAlignment = .left
        self.contentView.addSubview(titleLabel)
        
        posterImageView.contentMode = .scaleAspectFill
        posterImageView.clipsToBounds = true
        self.contentView.addSubview(posterImageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        selectedCountButton.frame = CGRect(x: self.contentView.tz_width - 50, y: 23, width: 24, height: 24)
        let titleHeight = ceil(self.titleLabel.font.lineHeight)
        self.titleLabel.frame = CGRect(x: 105, y: 0, width: self.tz_width - 80 - 50, height: self.contentView.tz_height)
        
        self.posterImageView.frame = CGRect(x: 20, y: 10, width: 70, height: 70)
        self.albumCellDidLayoutSubviewsClosure?(self, posterImageView, titleLabel)
    }

}


