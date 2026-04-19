#!/bin/bash
# =================================================================
# 🌿 GREENMIND — Step 8: Auth — Xác thực đăng nhập Dashboard
# =================================================================

setup_auth() {
    echo -e "\n${BOLD}${YELLOW}[$CURRENT_STEP/$TOTAL_STEPS] BẢO MẬT DASHBOARD${NC}"

    if [[ "$NODE_ROLE" == "node" ]]; then
        echo -e "${YELLOW}⏭ Chế độ Node — Bỏ qua Auth.${NC}"
        return 0
    fi

    echo -e "${CYAN}🔐 Thiết lập mật khẩu đăng nhập Dashboard.${NC}"
    echo -e "   Nếu bỏ qua, dashboard sẽ không có mật khẩu (chỉ nên dùng trong LAN nội bộ).\n"
    read -p "👉 Thiết lập mật khẩu đăng nhập? (y/n, mặc định y): " setup_pass </dev/tty
    setup_pass="${setup_pass:-y}"

    if [[ ! "$setup_pass" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}⏭ Bỏ qua — Dashboard không có xác thực.${NC}"
        echo "DASHBOARD_AUTH=false" >> "$CONFIG_FILE"
        return 0
    fi

    local username password password2

    read -p "Tên đăng nhập (mặc định: admin): " username </dev/tty
    username="${username:-admin}"

    while true; do
        read -sp "Mật khẩu: " password; echo
        read -sp "Nhập lại:  " password2; echo
        [[ "$password" == "$password2" ]] && break
        echo -e "${RED}❌ Mật khẩu không khớp, thử lại.${NC}"
    done

    # Hash mật khẩu bằng bcrypt qua Python
    local hashed
    hashed=$("$VENV_PATH/bin/python3" -c "
import hashlib, os
salt = os.urandom(16).hex()
h = hashlib.sha256((salt + '$password').encode()).hexdigest()
print(salt + ':' + h)
" 2>/dev/null)

    # Cài thư viện auth cho dashboard
    run_with_process "Cài thư viện xác thực" "$VENV_PATH/bin/pip" install \
        "python-jose[cryptography]" "passlib[bcrypt]" python-multipart -q

    # Ghi vào config
    grep -q "DASHBOARD_AUTH" "$CONFIG_FILE" && \
        sed -i "s/DASHBOARD_AUTH=.*/DASHBOARD_AUTH=true/" "$CONFIG_FILE" || \
        echo "DASHBOARD_AUTH=true" >> "$CONFIG_FILE"

    # Lưu credentials vào file riêng (không nằm trong config.env)
    local auth_file="/etc/greenmind/auth.env"
    cat > "$auth_file" <<EOF
DASHBOARD_USER=$username
DASHBOARD_PASS_HASH=$hashed
DASHBOARD_SECRET=$(openssl rand -hex 32)
EOF
    chmod 600 "$auth_file"

    echo -e "${GREEN} [✓] Đã thiết lập đăng nhập: ${BOLD}$username${NC}"
    echo -e "${CYAN}     Credentials: $auth_file${NC}"
}
